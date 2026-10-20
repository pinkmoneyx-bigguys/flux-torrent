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

#include <functional>
#include <utility>

#include <QList>
#include <QtTypes>

// Where a file lies in its torrent's pieces
struct StreamLayout
{
    qint64 fileSize = 0;
    qint64 pieceLength = 0;
    int firstPiece = 0;          // the piece holding the file's first byte
    qint64 firstPieceOffset = 0; // the offset of that byte inside the piece
};

// How far ahead of the playback position to read
enum class StreamMode
{
    Fast,    // a small window: playback starts soonest
    Smooth,  // four minutes at the bitrate: survives slow swarms
    Economy  // the smallest window: the rest of the torrent keeps its pace
};

// The read-ahead plan of a stream: which pieces get a deadline and how urgent each is. Pure logic, so it
// is tested without libtorrent; StreamSession hands the plan to Torrent::setPieceDeadlines.
//   - the window from the position gets deadlines base + i·step, the nearest piece first;
//   - the first 4 MiB of the file (container header) and the last 2 % (1…32 MiB, the MKV/MP4 index)
//     follow right after, so the player can open the file and seek.
// Pieces already downloaded get no deadline.
class StreamPlanner
{
public:
    static constexpr int DEADLINE_STEP_MS = 80;
    static constexpr int HEAD_DEADLINE_MS = 100;
    static constexpr int TAIL_DEADLINE_MS = 200;

    static int pieceOf(const StreamLayout &layout, qint64 fileOffset);
    static int lastPiece(const StreamLayout &layout);
    // Read-ahead size for a mode; `bytesPerSecond` is the media bitrate (0: unknown)
    static qint64 windowBytes(StreamMode mode, qint64 bytesPerSecond);

    // {piece, deadline ms}, nearest first
    static QList<std::pair<int, int>> plan(const StreamLayout &layout, qint64 position, StreamMode mode
            , qint64 bytesPerSecond, const std::function<bool (int piece)> &have);

    // Whether reading at `newPosition` moved far enough from the planned one to place a new window
    static bool needsReplan(const StreamLayout &layout, qint64 plannedPosition, qint64 newPosition
            , StreamMode mode, qint64 bytesPerSecond);
};
