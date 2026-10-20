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

#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// Everything the details pane of the Transfers screen shows about one torrent: facts, the piece map,
// files (with priorities), trackers and peers. Refreshed every second while `active`. Without a session
// torrent of that id it falls back to the TorrentListModel row (demo and test rows).
class TorrentDetails : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TorrentDetails)
    QML_ELEMENT

    Q_PROPERTY(QString torrentId READ torrentId WRITE setTorrentId NOTIFY torrentIdChanged FINAL)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged FINAL)
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed FINAL)
    // 0..1 share of pieces present in each of `pieceBuckets` equal slices of the torrent
    Q_PROPERTY(QVariantList pieces READ pieces NOTIFY changed FINAL)
    Q_PROPERTY(int pieceBuckets READ pieceBuckets WRITE setPieceBuckets NOTIFY changed FINAL)
    // {index, path, name, size, progress, priority}; priority 0 skip, 1 normal, 6 high, 7 maximum
    Q_PROPERTY(QVariantList files READ files NOTIFY changed FINAL)
    // {url, tier, status ("working", "notWorking", "error", "unreachable", "notContacted", "disabled"), message, seeds, peers}
    Q_PROPERTY(QVariantList trackers READ trackers NOTIFY changed FINAL)
    // {address, client, progress, dlSpeed, upSpeed, country, connection}
    Q_PROPERTY(QVariantList peers READ peers NOTIFY peersChanged FINAL)

public:
    explicit TorrentDetails(QObject *parent = nullptr);

    QString torrentId() const;
    void setTorrentId(const QString &id);
    bool active() const;
    void setActive(bool active);
    int pieceBuckets() const;
    void setPieceBuckets(int buckets);

    QVariantMap info() const;
    QVariantList pieces() const;
    QVariantList files() const;
    QVariantList trackers() const;
    QVariantList peers() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setFilePriority(int fileIndex, int priority);

signals:
    void torrentIdChanged();
    void activeChanged();
    void changed();
    void peersChanged();

private:
    void fetchPeers();

    QString m_torrentId;
    bool m_active = false;
    int m_pieceBuckets = 160;
    QVariantMap m_info;
    QVariantList m_pieces;
    QVariantList m_files;
    QVariantList m_trackers;
    QVariantList m_peers;
    QTimer m_timer;
    int m_peerRequest = 0;
};
