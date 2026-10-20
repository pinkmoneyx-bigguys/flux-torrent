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

#include "torrentdetails.h"

#include <QBitArray>
#include <QFuture>
#include <QQmlEngine>

#include "base/bittorrent/downloadpriority.h"
#include "base/bittorrent/infohash.h"
#include "base/bittorrent/peeraddress.h"
#include "base/bittorrent/peerinfo.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/bittorrent/trackerentrystatus.h"
#include "base/global.h"
#include "base/path.h"
#include "torrentlistmodel.h"

using BitTorrent::Torrent;

namespace
{
    QString trackerStatusKey(const BitTorrent::TrackerEndpointState state)
    {
        switch (state)
        {
        case BitTorrent::TrackerEndpointState::Working: return u"working"_s;
        case BitTorrent::TrackerEndpointState::NotWorking: return u"notWorking"_s;
        case BitTorrent::TrackerEndpointState::TrackerError: return u"error"_s;
        case BitTorrent::TrackerEndpointState::Unreachable: return u"unreachable"_s;
        default: return u"notContacted"_s;
        }
    }

    Torrent *sessionTorrent(const QString &id)
    {
        const auto *session = BitTorrent::Session::instance();
        return (session && !id.isEmpty()) ? session->getTorrent(BitTorrent::TorrentID::fromString(id)) : nullptr;
    }
}

TorrentDetails::TorrentDetails(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &TorrentDetails::refresh);
}

QString TorrentDetails::torrentId() const
{
    return m_torrentId;
}

void TorrentDetails::setTorrentId(const QString &id)
{
    if (id == m_torrentId)
        return;

    m_torrentId = id;
    m_peers.clear();
    ++m_peerRequest; // drop answers for the previous torrent
    emit torrentIdChanged();
    emit peersChanged();
    refresh();
}

bool TorrentDetails::active() const
{
    return m_active;
}

void TorrentDetails::setActive(const bool active)
{
    if (active == m_active)
        return;

    m_active = active;
    if (m_active)
    {
        refresh();
        m_timer.start();
    }
    else
    {
        m_timer.stop();
    }
    emit activeChanged();
}

int TorrentDetails::pieceBuckets() const
{
    return m_pieceBuckets;
}

void TorrentDetails::setPieceBuckets(const int buckets)
{
    if ((buckets == m_pieceBuckets) || (buckets < 1))
        return;

    m_pieceBuckets = buckets;
    refresh();
}

QVariantMap TorrentDetails::info() const
{
    return m_info;
}

QVariantList TorrentDetails::pieces() const
{
    return m_pieces;
}

QVariantList TorrentDetails::files() const
{
    return m_files;
}

QVariantList TorrentDetails::trackers() const
{
    return m_trackers;
}

QVariantList TorrentDetails::peers() const
{
    return m_peers;
}

void TorrentDetails::refresh()
{
    m_info.clear();
    m_pieces.clear();
    m_files.clear();
    m_trackers.clear();

    const Torrent *torrent = sessionTorrent(m_torrentId);
    if (!torrent)
    {
        // Demo and test rows: what the list model knows, plus the lists the row carries
        QQmlEngine *engine = qmlEngine(this);
        auto *model = engine ? engine->singletonInstance<TorrentListModel *>(u"Flux"_s, u"TorrentListModel"_s) : nullptr;
        if (model && !m_torrentId.isEmpty())
        {
            m_info = model->get(m_torrentId);
            const QVariantMap extra = m_info.take(u"extra"_s).toMap();
            m_files = extra.value(u"files"_s).toList();
            m_trackers = extra.value(u"trackers"_s).toList();
            m_pieces = extra.value(u"pieces"_s).toList();
            if (m_peers != extra.value(u"peerList"_s).toList())
            {
                m_peers = extra.value(u"peerList"_s).toList();
                emit peersChanged();
            }
        }
        emit changed();
        return;
    }

    QQmlEngine *engine = qmlEngine(this);
    auto *model = engine ? engine->singletonInstance<TorrentListModel *>(u"Flux"_s, u"TorrentListModel"_s) : nullptr;
    if (model)
        m_info = model->get(m_torrentId);
    m_info.remove(u"extra"_s);
    m_info.insert(u"hash"_s, torrent->infoHash().v1().isValid() ? torrent->infoHash().v1().toString() : torrent->infoHash().v2().toString());
    m_info.insert(u"comment"_s, torrent->comment());
    m_info.insert(u"creator"_s, torrent->creator());
    m_info.insert(u"createdOn"_s, torrent->creationDate());
    m_info.insert(u"isPrivate"_s, torrent->isPrivate());
    m_info.insert(u"piecesCount"_s, torrent->piecesCount());
    m_info.insert(u"piecesHave"_s, torrent->piecesHave());
    m_info.insert(u"pieceLength"_s, torrent->pieceLength());
    m_info.insert(u"connections"_s, torrent->connectionsCount());
    m_info.insert(u"availability"_s, torrent->distributedCopies());
    m_info.insert(u"activeTime"_s, torrent->activeTime());
    m_info.insert(u"hasMetadata"_s, torrent->hasMetadata());

    // Piece map: the share of present pieces in each bucket
    const QBitArray have = torrent->pieces();
    const qsizetype n = have.size();
    if (n > 0)
    {
        const int buckets = static_cast<int>(std::min<qsizetype>(m_pieceBuckets, n));
        m_pieces.reserve(buckets);
        for (int b = 0; b < buckets; ++b)
        {
            const qsizetype from = n * b / buckets;
            const qsizetype to = std::max(from + 1, n * (b + 1) / buckets);
            qsizetype count = 0;
            for (qsizetype i = from; i < to; ++i)
                count += have.testBit(i) ? 1 : 0;
            m_pieces.append(static_cast<double>(count) / static_cast<double>(to - from));
        }
    }

    if (torrent->hasMetadata())
    {
        const QList<BitTorrent::DownloadPriority> priorities = torrent->filePriorities();
        const QList<qreal> progress = torrent->filesProgress();
        const int count = torrent->filesCount();
        m_files.reserve(count);
        for (int i = 0; i < count; ++i)
        {
            const Path path = torrent->filePath(i);
            m_files.append(QVariantMap {
                {u"index"_s, i},
                {u"path"_s, path.toString()},
                {u"name"_s, path.filename()},
                {u"size"_s, torrent->fileSize(i)},
                {u"progress"_s, (i < progress.size()) ? progress.at(i) : 0.0},
                {u"priority"_s, (i < priorities.size()) ? static_cast<int>(priorities.at(i)) : 1}
            });
        }
    }

    for (const BitTorrent::TrackerEntryStatus &tracker : torrent->trackers())
    {
        m_trackers.append(QVariantMap {
            {u"url"_s, tracker.url},
            {u"tier"_s, tracker.tier},
            {u"status"_s, trackerStatusKey(tracker.state)},
            {u"message"_s, tracker.message},
            {u"seeds"_s, tracker.numSeeds},
            {u"peers"_s, tracker.numLeeches}
        });
    }

    emit changed();
    if (m_active)
        fetchPeers();
}

void TorrentDetails::fetchPeers()
{
    const Torrent *torrent = sessionTorrent(m_torrentId);
    if (!torrent)
        return;

    const int request = ++m_peerRequest;
    torrent->fetchPeerInfo().then(this, [this, request](const QList<BitTorrent::PeerInfo> &peers)
    {
        if (request != m_peerRequest)
            return;

        QVariantList list;
        list.reserve(peers.size());
        for (const BitTorrent::PeerInfo &peer : peers)
        {
            list.append(QVariantMap {
                {u"address"_s, peer.address().toString()},
                {u"client"_s, peer.client()},
                {u"progress"_s, peer.progress()},
                {u"dlSpeed"_s, peer.payloadDownSpeed()},
                {u"upSpeed"_s, peer.payloadUpSpeed()},
                {u"country"_s, peer.country()},
                {u"connection"_s, peer.connectionType()}
            });
        }
        m_peers = list;
        emit peersChanged();
    });
}

void TorrentDetails::setFilePriority(const int fileIndex, const int priority)
{
    Torrent *torrent = sessionTorrent(m_torrentId);
    if (!torrent || !torrent->hasMetadata())
        return;

    QList<BitTorrent::DownloadPriority> priorities = torrent->filePriorities();
    if ((fileIndex < 0) || (fileIndex >= priorities.size()))
        return;

    priorities[fileIndex] = static_cast<BitTorrent::DownloadPriority>(priority);
    torrent->prioritizeFiles(priorities);
    refresh();
}
