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

#include "jacredsearch.h"
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
    ReleaseMeta meta;   // what the source knows beyond the name (JacRed)
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
    void append(const QList<JacRedResult> &results);
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
    // What was searched for: with `exact`, only releases whose titles have its words stay. A tracker also
    // finds the words in genres and descriptions ("киберпанк" brings "Serial Experiments Lain").
    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY filterChanged FINAL)
    Q_PROPERTY(bool exact READ exact WRITE setExact NOTIFY filterChanged FINAL)
    // how many results `exact` leaves out
    Q_PROPERTY(int looseCount READ looseCount NOTIFY looseCountChanged FINAL)
    // The shown results by film (FilmInfo), in the current order: [{key, title, original, year, series,
    // qualities, count, seeds, minSize, maxSize, voices}], for the cards: without the releases (QML would
    // carry every film's hundreds of them each time it reads the list). Rebuilt shortly after the results
    // change. `voices` of a film: every voice-over of its releases, the most common first.
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
    QString query() const;
    void setQuery(const QString &query);
    bool exact() const;
    void setExact(bool exact);
    int looseCount() const;

    // Whether a release's titles (not its genres or notes) have the words of `query`: most of them, each
    // word by its stem ("киберпанка" finds "Киберпанк"); a query of no real words matches everything
    static bool titlesMatch(const QString &name, const ReleaseMeta &meta, const QString &query);

    // The source row of visible row `row` (for SearchEngine.download), or -1
    Q_INVOKABLE int sourceRow(int row) const;
    QVariantList groups() const;
    // One film of `groups` with its releases: [{row, name, size, seeds, leechers, engine, fileUrl,
    // published, downloaded, quality, voices, tags}]; {} when it is not shown
    Q_INVOKABLE QVariantMap group(const QString &key) const;
    // Builds the groups now (tests)
    Q_INVOKABLE void regroup();

    // What a release is, for the chips beside its name, in this order: {kind, text} with kind "quality"
    // ("4K", "1080p"), "hdr" ("HDR", "Dolby Vision"), "source" ("WEB-DL", "BDRip"…), "codec" ("HEVC"),
    // "season" (text "1" or "1–2"), "episodes" (text "1–10/10"), "audio" (text "dub", "mvo", "dvo", "avo",
    // "pro", "amateur", "sub", "original": the kinds of voice-over the name gives)
    static QVariantList tagsOf(const QString &name, const ReleaseMeta &meta = {});
    // The kind ("dub", "mvo"… as in tagsOf) a source's voice-over names rather than a studio, or ""
    static QString voiceKind(const QString &voice);
    // The studios among a source's voice-overs (the kinds go to the tags)
    static QStringList studiosOf(const QStringList &voices);
    // The film of a release from its name, with what its source knows put first
    static FilmInfo filmOfRelease(const QString &name, const ReleaseMeta &meta);

signals:
    void filterChanged();
    void sortChanged();
    void countChanged();
    void groupsChanged();
    void looseCountChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    void applySort();

    QString m_search;
    QStringList m_words;
    bool m_seededOnly = false;
    bool m_postersOnly = false;
    QString m_query;
    bool m_exact = true;
    int m_looseCount = 0;
    // counts the results `exact` leaves out
    void countLoose();
    // works out every release's film (shown or not; see regroup) and asks Posters about them
    void resolveFilms();
    // whether the query names the release or its film (`exact`)
    bool matchesQuery(const SearchRow &row) const;
    QSet<QString> m_namedFilms;  // the films the query names (keys), worked out with the films
    // the film of a release (filmOfRelease), then joined as resolveFilms decided
    FilmInfo filmOf(const SearchRow &row) const;
    QHash<QString, FilmInfo> m_resolved;  // key as parsed → the film
    QString m_sortKey;
    bool m_descending = false;
    QVariantList m_groups;                  // without the releases
    QHash<QString, QVariantMap> m_fullGroups; // key → with them
    QTimer *m_groupTimer = nullptr;
};
