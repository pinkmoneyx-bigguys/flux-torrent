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
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

namespace BitTorrent
{
    class Torrent;
}

// One torrent as the list shows it: plain values copied from the core on every update
struct TorrentRow
{
    QString id;
    QString name;
    QString state;          // see TorrentListModel::stateKey()
    QString category;
    QString tags;
    QString savePath;
    QString error;
    qint64 size = 0;        // wanted size
    qint64 totalSize = 0;
    qint64 done = 0;        // completed bytes of the wanted files
    qint64 downloaded = 0;  // all-time payload, this torrent
    qint64 uploaded = 0;
    qint64 dlSpeed = 0;
    qint64 upSpeed = 0;
    qint64 eta = 0;         // seconds; >= 8640000 means unknown
    qreal progress = 0;
    qreal ratio = 0;
    int seeds = 0;
    int seedsTotal = 0;
    int peers = 0;
    int peersTotal = 0;
    int queuePosition = -1;
    QDateTime added;
    QDateTime completed;
    // Demo/test rows only: "files", "trackers", "peers" lists for the details pane
    QVariantMap extra;

    static TorrentRow fromTorrent(const BitTorrent::Torrent *torrent);
    static TorrentRow fromVariant(const QVariantMap &map);
};

// The torrents of the session as a flat list model, with per-status counts for the filter tabs and the
// actions of the Transfers screen. Rows are snapshots refreshed on Session::torrentsUpdated; without a
// session (tests, FLUX_DEMO_TORRENTS=<json file>) the rows come from setRows().
class TorrentListModel : public QAbstractListModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TorrentListModel)
    QML_ELEMENT
    QML_SINGLETON

    // {all, downloading, seeding, completed, stopped, active, errored}: number of rows in each filter
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY countsChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countsChanged FINAL)

public:
    enum Role
    {
        IdRole = Qt::UserRole + 1,
        NameRole,
        StateRole,
        CategoryRole,
        TagsRole,
        SavePathRole,
        ErrorRole,
        SizeRole,
        TotalSizeRole,
        DoneRole,
        DownloadedRole,
        UploadedRole,
        DlSpeedRole,
        UpSpeedRole,
        EtaRole,
        ProgressRole,
        RatioRole,
        SeedsRole,
        SeedsTotalRole,
        PeersRole,
        PeersTotalRole,
        QueuePositionRole,
        AddedRole,
        CompletedRole
    };
    Q_ENUM(Role)

    explicit TorrentListModel(QObject *parent = nullptr);

    static TorrentListModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // "downloading", "seeding", "stalledDl", "stalledUp", "queuedDl", "queuedUp", "checking", "metadata",
    // "stoppedDl" (incomplete, stopped), "stoppedUp" (complete, stopped), "moving", "missing", "error"
    static QString stateKey(int torrentState);
    // Whether a row belongs to a filter tab: "all", "downloading", "seeding", "completed", "stopped",
    // "active", "errored"
    static bool matchesStatus(const TorrentRow &row, const QString &status);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QVariantMap counts() const;
    const TorrentRow *row(const QString &id) const;
    const TorrentRow *rowAt(int i) const;

    // Replaces every row (tests and the demo file); detaches from the session updates
    Q_INVOKABLE void setRows(const QVariantList &rows);
    // The row of `id` as a JS object, or an empty one
    Q_INVOKABLE QVariantMap get(const QString &id) const;

    Q_INVOKABLE void start(const QStringList &ids);
    Q_INVOKABLE void stop(const QStringList &ids);
    Q_INVOKABLE void forceStart(const QStringList &ids);
    Q_INVOKABLE void remove(const QStringList &ids, bool deleteFiles);
    Q_INVOKABLE void recheck(const QStringList &ids);
    Q_INVOKABLE void reannounce(const QStringList &ids);
    Q_INVOKABLE void queueTop(const QStringList &ids);
    Q_INVOKABLE void queueUp(const QStringList &ids);
    Q_INVOKABLE void queueDown(const QStringList &ids);
    Q_INVOKABLE void queueBottom(const QStringList &ids);
    // Copies the magnet links of `ids` (one per line) to the clipboard; returns how many were copied
    Q_INVOKABLE int copyMagnets(const QStringList &ids);
    Q_INVOKABLE void openFolder(const QString &id);
    // Adds a .torrent file or a magnet link / info hash; returns "" on success or the error text
    Q_INVOKABLE QString addFile(const QUrl &fileUrl);
    Q_INVOKABLE QString addLink(const QString &link);

signals:
    void countsChanged();

private:
    void onTorrentsLoaded(const QList<BitTorrent::Torrent *> &torrents);
    void onTorrentAboutToBeRemoved(BitTorrent::Torrent *torrent);
    void onTorrentsUpdated(const QList<BitTorrent::Torrent *> &torrents);
    void appendRows(const QList<TorrentRow> &rows);
    void reindex(int from);
    void updateCounts();
    QList<BitTorrent::Torrent *> torrentsOf(const QStringList &ids) const;

    QList<TorrentRow> m_rows;
    QHash<QString, int> m_index;
    QVariantMap m_counts;
    bool m_detached = false;
};
