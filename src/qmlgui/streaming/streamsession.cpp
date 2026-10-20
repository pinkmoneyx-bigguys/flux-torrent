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

#include "streamsession.h"

#include <algorithm>

#include "base/bittorrent/downloadpriority.h"
#include "base/bittorrent/infohash.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/global.h"
#include "base/path.h"

using BitTorrent::Torrent;

StreamSession::StreamSession(Torrent *torrent, const int fileIndex, StreamStateStore *store, QObject *parent)
    : StreamSource(parent)
    , m_torrent {torrent}
    , m_fileIndex {fileIndex}
    , m_store {store}
{
}

StreamSession::~StreamSession()
{
    close();
}

QString StreamSession::open(const StreamMode mode)
{
    if (m_open)
        return {};

    Torrent *torrent = m_torrent;
    if (!torrent)
        return tr("The torrent is gone.");
    if (!torrent->hasMetadata())
        return tr("The torrent has no file list yet.");
    if ((m_fileIndex < 0) || (m_fileIndex >= torrent->filesCount()))
        return tr("There is no such file in the torrent.");

    m_mode = mode;
    m_fileName = torrent->filePath(m_fileIndex).filename();
    m_layout.fileSize = torrent->fileSize(m_fileIndex);
    m_layout.pieceLength = torrent->pieceLength();
    const auto [firstPiece, offset] = torrent->mapFileOffset(m_fileIndex, 0);
    m_layout.firstPiece = firstPiece;
    m_layout.firstPieceOffset = offset;

    // write down what is about to change before changing it
    m_record.torrentId = torrent->id().toString();
    m_record.fileIndex = m_fileIndex;
    m_record.wasStopped = torrent->isStopped();
    m_record.wasForced = torrent->isForced();
    m_record.openedAt = QDateTime::currentDateTimeUtc();
    if (m_store)
        m_store->add(m_record);

    // a file chosen for watching downloads, and stays on afterwards
    QList<BitTorrent::DownloadPriority> priorities = torrent->filePriorities();
    if ((m_fileIndex < priorities.size()) && (priorities.at(m_fileIndex) == BitTorrent::DownloadPriority::Ignored))
    {
        priorities[m_fileIndex] = BitTorrent::DownloadPriority::Normal;
        torrent->prioritizeFiles(priorities);
        m_enabledSkippedFile = true;
    }

    // watching needs the torrent running, whatever the queue says
    if (torrent->isStopped() || torrent->isQueued())
    {
        torrent->start(BitTorrent::TorrentOperatingMode::Forced);
        m_startedTorrent = true;
    }

    auto *session = BitTorrent::Session::instance();
    session->setPieceAlertsEnabled(true);
    connect(session, &BitTorrent::Session::pieceFinished, this, [this](Torrent *t, const int piece)
    {
        if ((t == m_torrent) && (piece >= m_layout.firstPiece) && (piece <= StreamPlanner::lastPiece(m_layout)))
            emit dataAvailable();
    });
    connect(session, &BitTorrent::Session::torrentAboutToBeRemoved, this, &StreamSession::onTorrentRemoved);

    m_open = true;
    replan(0);
    return {};
}

void StreamSession::close()
{
    if (!m_open)
        return;
    m_open = false;

    if (auto *session = BitTorrent::Session::instance())
    {
        disconnect(session, nullptr, this, nullptr);
        session->setPieceAlertsEnabled(false);
    }
    if (Torrent *torrent = m_torrent)
    {
        torrent->clearPieceDeadlines();
        if (m_startedTorrent)
            restoreTorrent(torrent, m_record);
    }
    if (m_store)
        m_store->remove(m_record.torrentId, m_record.fileIndex);
    m_file.close();
}

void StreamSession::restoreTorrent(Torrent *torrent, const StreamRecord &record)
{
    if (!torrent)
        return;
    torrent->clearPieceDeadlines();
    if (record.wasStopped)
        torrent->stop();
    else if (!record.wasForced && torrent->isForced())
        torrent->start(BitTorrent::TorrentOperatingMode::AutoManaged); // back in the queue
}

void StreamSession::onTorrentRemoved(Torrent *torrent)
{
    if (torrent != m_torrent)
        return;

    // nothing to give back: just stop listening and forget the record
    m_open = false;
    if (auto *session = BitTorrent::Session::instance())
    {
        disconnect(session, nullptr, this, nullptr);
        session->setPieceAlertsEnabled(false);
    }
    if (m_store)
        m_store->remove(m_record.torrentId, m_record.fileIndex);
    m_torrent = nullptr;
    m_file.close();
    emit dataAvailable(); // waiting readers find nothing and time out
}

bool StreamSession::isOpen() const
{
    return m_open;
}

QString StreamSession::torrentId() const
{
    return m_record.torrentId;
}

int StreamSession::fileIndex() const
{
    return m_fileIndex;
}

bool StreamSession::enabledSkippedFile() const
{
    return m_enabledSkippedFile;
}

StreamMode StreamSession::mode() const
{
    return m_mode;
}

void StreamSession::setMode(const StreamMode mode)
{
    if (mode == m_mode)
        return;
    m_mode = mode;
    if (m_open)
        replan(m_plannedPosition);
}

void StreamSession::setBitrate(const qint64 bytesPerSecond)
{
    if (bytesPerSecond == m_bitrate)
        return;
    m_bitrate = bytesPerSecond;
    if (m_open && (m_mode == StreamMode::Smooth))
        replan(m_plannedPosition);
}

qint64 StreamSession::size() const
{
    return m_layout.fileSize;
}

QString StreamSession::fileName() const
{
    return m_fileName;
}

qint64 StreamSession::pieceEndInFile(const int piece) const
{
    // the file offset right after `piece`
    return (static_cast<qint64>(piece - m_layout.firstPiece + 1) * m_layout.pieceLength) - m_layout.firstPieceOffset;
}

qint64 StreamSession::available(const qint64 offset, const qint64 maxLength) const
{
    const Torrent *torrent = m_torrent;
    if (!torrent || (offset >= m_layout.fileSize) || (maxLength <= 0))
        return 0;

    const qint64 wantedEnd = std::min(m_layout.fileSize, offset + maxLength);
    qint64 end = offset;
    for (int piece = StreamPlanner::pieceOf(m_layout, offset); end < wantedEnd; ++piece)
    {
        if (!torrent->havePiece(piece))
            break;
        end = std::min(wantedEnd, pieceEndInFile(piece));
    }
    return end - offset;
}

QString StreamSession::diskPath() const
{
    const Torrent *torrent = m_torrent;
    if (!torrent)
        return {};
    const Path relative = torrent->actualFilePath(m_fileIndex);
    return (relative.isAbsolute() ? relative : (torrent->actualStorageLocation() / relative)).data();
}

QByteArray StreamSession::read(const qint64 offset, const qint64 length)
{
    // the file moves when it completes (".!qB" dropped, incomplete folder left): follow it
    const QString path = diskPath();
    if (path.isEmpty())
        return {};
    if ((m_file.fileName() != path) || !m_file.isOpen())
    {
        m_file.close();
        m_file.setFileName(path);
        if (!m_file.open(QIODevice::ReadOnly))
            return {};
    }
    if (!m_file.seek(offset))
        return {};
    return m_file.read(length);
}

void StreamSession::noteRead(const qint64 offset)
{
    m_lastRead = offset;
    if (m_open && StreamPlanner::needsReplan(m_layout, m_plannedPosition, offset, m_mode, m_bitrate))
        replan(offset);
}

void StreamSession::replan(const qint64 position)
{
    Torrent *torrent = m_torrent;
    if (!torrent)
        return;

    m_plannedPosition = position;
    const auto plan = StreamPlanner::plan(m_layout, position, m_mode, m_bitrate
        , [torrent](const int piece) { return torrent->havePiece(piece); });
    torrent->clearPieceDeadlines();
    torrent->setPieceDeadlines(plan);
}

QVariantMap StreamSession::stats(const qint64 fromByte) const
{
    const qint64 from = (fromByte >= 0) ? std::min(fromByte, m_layout.fileSize) : m_lastRead;
    Torrent *torrent = m_torrent;
    const qint64 window = StreamPlanner::windowBytes(m_mode, m_bitrate);
    // the buffer gauge looks at most 128 MiB ahead: each piece is a call into libtorrent
    constexpr qint64 GAUGE_LIMIT = 128 * 1024 * 1024;
    const QList<qreal> progress = torrent ? torrent->filesProgress() : QList<qreal> {};
    return {
        {u"position"_s, m_lastRead},
        {u"size"_s, m_layout.fileSize},
        {u"bufferedAhead"_s, available(from, std::min(window, GAUGE_LIMIT))},
        {u"window"_s, window},
        {u"downloadRate"_s, torrent ? torrent->downloadPayloadRate() : 0},
        {u"complete"_s, (m_fileIndex < progress.size()) && (progress.at(m_fileIndex) >= 1)},
        {u"open"_s, m_open}
    };
}
