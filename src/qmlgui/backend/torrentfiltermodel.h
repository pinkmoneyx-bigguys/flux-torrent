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

#include <QSortFilterProxyModel>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

// The Transfers list as shown: TorrentListModel filtered by a status tab and the search text, sorted by
// one column. Set sourceModel to TorrentListModel.
class TorrentFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TorrentFilterModel)
    QML_ELEMENT

    // "all", "downloading", "seeding", "completed", "stopped", "active", "errored"
    Q_PROPERTY(QString status READ status WRITE setStatus NOTIFY statusChanged FINAL)
    // Case-insensitive; every word must occur in the name, the category or the tags
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged FINAL)
    // A role name of TorrentListModel ("name", "size", "progress", "dlSpeed", ...); "" keeps the source order
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY sortChanged FINAL)
    Q_PROPERTY(bool descending READ descending WRITE setDescending NOTIFY sortChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)

public:
    explicit TorrentFilterModel(QObject *parent = nullptr);

    QString status() const;
    void setStatus(const QString &status);
    QString search() const;
    void setSearch(const QString &search);
    QString sortKey() const;
    void setSortKey(const QString &key);
    bool descending() const;
    void setDescending(bool descending);
    int count() const;

    // The torrent id of the visible row `row`, or ""
    Q_INVOKABLE QString idAt(int row) const;
    // The visible row of `id`, or -1
    Q_INVOKABLE int rowOf(const QString &id) const;
    // Ids of the visible rows from `first` to `last` (any order), for shift-selection
    Q_INVOKABLE QStringList idsBetween(int first, int last) const;

signals:
    void statusChanged();
    void searchChanged();
    void sortChanged();
    void countChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;
    bool lessThan(const QModelIndex &left, const QModelIndex &right) const override;

private:
    void applySort();

    QString m_status = QStringLiteral("all");
    QString m_search;
    QStringList m_words;
    QString m_sortKey;
    bool m_descending = false;
};
