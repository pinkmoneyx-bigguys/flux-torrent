/*
 * Bittorrent Client using Qt and libtorrent.
 * Copyright (C) 2026  Flux contributors
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * In addition, as a special exception, the copyright holders give permission to
 * link this program with the OpenSSL project's "OpenSSL" library (or with
 * modified versions of it that use the same license as the "OpenSSL" library),
 * and distribute the linked executables. You must obey the GNU General Public
 * License in all respects for all of the code used other than "OpenSSL".  If you
 * modify file(s), you may extend this exception to your version of the file(s),
 * but you are not obligated to do so. If you do not wish to do so, delete this
 * exception statement from your version.
 */

#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QHash>
#include <QList>
#include <QSet>
#include <QSortFilterProxyModel>
#include <QTimer>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

#include "posters.h"

struct SearchResult;

// One search hit as the results table shows it
struct SearchRow
{
    QString name;
    QString fileUrl;
    QString descrLink;
    QString engine;     // plugin name
    QString siteUrl;
    qint64 size = -1;
    qint64 seeds = -1;
    qint64 leechers = -1;
    QDateTime published;
    bool downloaded = false;
};

// Results of the current tracker search, in arrival order
class SearchResultsModel : public QAbstractListModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(SearchResultsModel)
    QML_ELEMENT
    QML_UNCREATABLE("Owned by SearchEngine")

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Role
    {
        NameRole = Qt::UserRole + 1,
        FileUrlRole,
        DescrLinkRole,
        EngineRole,
        SiteUrlRole,
        SizeRole,
        SeedsRole,
        LeechersRole,
        PublishedRole,
        DownloadedRole
    };

    explicit SearchResultsModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    const SearchRow *rowAt(int i) const;
    void clear();
    void append(const QList<SearchResult> &results);
    // Tests and the demo file: rows as {name, fileUrl, descrLink, engine, siteUrl, size, seeds, leechers, publishedSecsAgo}
    Q_INVOKABLE void setRows(const QVariantList &rows);
    void markDownloaded(int row);

signals:
    void countChanged();

private:
    QList<SearchRow> m_rows;
};

// The results as shown: filtered by words in the name and by "has seeds", sorted by one role
class SearchResultsFilter : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(SearchResultsFilter)
    QML_ELEMENT

    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY filterChanged FINAL)
    Q_PROPERTY(bool seededOnly READ seededOnly WRITE setSeededOnly NOTIFY filterChanged FINAL)
    // only releases of films a poster was found for (Posters looks every film up, shown or not)
    Q_PROPERTY(bool postersOnly READ postersOnly WRITE setPostersOnly NOTIFY filterChanged FINAL)
    // A role name ("name", "size", "seeds", "leechers", "engine", "published"); "" keeps the arrival order
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged FINAL)
    Q_PROPERTY(bool descending READ descending WRITE setDescending NOTIFY sortChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    // The shown results by film (FilmInfo), in the current order: [{key, title, original, year, series,
    // qualities, count, seeds, minSize, maxSize, releases: [{row, name, size, seeds, leechers, engine,
    // fileUrl, published, downloaded, quality}]}]. Rebuilt shortly after the results change.
    Q_PROPERTY(QVariantList groups READ groups NOTIFY groupsChanged FINAL)

public:
    explicit SearchResultsFilter(QObject *parent = nullptr);

    QString search() const;
    void setSearch(const QString &search);
    bool seededOnly() const;
    bool postersOnly() const;
    void setPostersOnly(bool on);
    void setSeededOnly(bool on);
    QString sortKey() const;
    void setSortKey(const QString &key);
    bool descending() const;
    void setDescending(bool descending);
    int count() const;

    // The source row of visible row `row` (for SearchEngine.download), or -1
    Q_INVOKABLE int sourceRow(int row) const;
    QVariantList groups() const;
    // Builds the groups now (tests)
    Q_INVOKABLE void regroup();

signals:
    void filterChanged();
    void sortChanged();
    void countChanged();
    void groupsChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    void applySort();

    QString m_search;
    QStringList m_words;
    bool m_seededOnly = false;
    bool m_postersOnly = false;
    // works out every release's film (shown or not; see regroup) and asks Posters about them
    void resolveFilms();
    // the film of a release: parsed from its name, then joined as resolveFilms decided
    FilmInfo filmOf(const QString &name) const;
    QHash<QString, FilmInfo> m_resolved;  // key as parsed → the film
    QString m_sortKey;
    bool m_descending = false;
    QVariantList m_groups;
    QTimer *m_groupTimer = nullptr;
};
