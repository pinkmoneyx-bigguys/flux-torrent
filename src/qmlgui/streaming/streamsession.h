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

#include <QFile>
#include <QPointer>
#include <QString>
#include <QVariantMap>

#include "streamplanner.h"
#include "streamsource.h"
#include "streamstatestore.h"

namespace BitTorrent
{
    class Torrent;
}

// One stream: a file of a torrent being watched. As a StreamSource it serves the bytes already on disk;
// as the torrent's temporary owner it makes the file download in reading order and gives the torrent
// back afterwards:
//   open()  - records the torrent's state in streams.json, turns the file on if it was skipped (it stays
//             on), force-starts a stopped or queued torrent, enables piece-finished alerts and places the
//             read-ahead deadlines (StreamPlanner) for the start of the file;
//   reads   - every read moves the planned position; a seek or a long read places a new window;
//   close() - clears the deadlines, stops or re-queues the torrent if the stream started it, forgets the
//             record. Also when the torrent is removed meanwhile.
class StreamSession final : public StreamSource
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(StreamSession)

public:
    StreamSession(BitTorrent::Torrent *torrent, int fileIndex, StreamStateStore *store, QObject *parent = nullptr);
    ~StreamSession() override;

    // "" on success, otherwise why the file cannot be streamed
    QString open(StreamMode mode);
    void close();
    bool isOpen() const;

    QString torrentId() const;
    int fileIndex() const;
    // The file was marked "do not download" and the stream turned it on
    bool enabledSkippedFile() const;

    StreamMode mode() const;
    void setMode(StreamMode mode);
    // Media bitrate in bytes per second, from the player (0: unknown)
    void setBitrate(qint64 bytesPerSecond);

    // {position, bufferedAhead (bytes on disk in a row from the position), size, downloadRate, complete}
    QVariantMap stats() const;

    // StreamSource
    qint64 size() const override;
    QString fileName() const override;
    qint64 available(qint64 offset, qint64 maxLength) const override;
    QByteArray read(qint64 offset, qint64 length) override;
    void noteRead(qint64 offset) override;

    // Rolls back what a stream did to its torrent (also for records left by a crash)
    static void restoreTorrent(BitTorrent::Torrent *torrent, const StreamRecord &record);

private:
    void replan(qint64 position);
    qint64 pieceEndInFile(int piece) const;
    QString diskPath() const;
    void onTorrentRemoved(BitTorrent::Torrent *torrent);

    QPointer<BitTorrent::Torrent> m_torrent;
    int m_fileIndex = 0;
    StreamStateStore *m_store = nullptr;
    StreamRecord m_record;
    StreamLayout m_layout;
    StreamMode m_mode = StreamMode::Smooth;
    qint64 m_bitrate = 0;
    qint64 m_plannedPosition = 0;
    qint64 m_lastRead = 0;
    bool m_open = false;
    bool m_startedTorrent = false;
    bool m_enabledSkippedFile = false;
    QString m_fileName;
    QFile m_file;
};
