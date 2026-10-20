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

#include "streamplanner.h"

#include <algorithm>

#include <QSet>

namespace
{
    constexpr qint64 MiB = 1024 * 1024;
    constexpr qint64 HEAD_BYTES = 4 * MiB;
    constexpr qint64 DEFAULT_BITRATE = 3 * MiB; // bytes per second when the player has not told us yet
    constexpr qint64 SMOOTH_SECONDS = 240;
}

int StreamPlanner::pieceOf(const StreamLayout &layout, const qint64 fileOffset)
{
    if (layout.pieceLength <= 0)
        return layout.firstPiece;
    const qint64 offset = std::clamp<qint64>(fileOffset, 0, std::max<qint64>(0, layout.fileSize - 1));
    return layout.firstPiece + static_cast<int>((layout.firstPieceOffset + offset) / layout.pieceLength);
}

int StreamPlanner::lastPiece(const StreamLayout &layout)
{
    return pieceOf(layout, layout.fileSize - 1);
}

qint64 StreamPlanner::windowBytes(const StreamMode mode, const qint64 bytesPerSecond)
{
    switch (mode)
    {
    case StreamMode::Economy:
        return 8 * MiB;
    case StreamMode::Smooth:
        return std::clamp<qint64>(((bytesPerSecond > 0) ? bytesPerSecond : DEFAULT_BITRATE) * SMOOTH_SECONDS, 64 * MiB, 1024 * MiB);
    case StreamMode::Fast:
    default:
        return 16 * MiB;
    }
}

QList<std::pair<int, int>> StreamPlanner::plan(const StreamLayout &layout, const qint64 position, const StreamMode mode
        , const qint64 bytesPerSecond, const std::function<bool (int)> &have)
{
    QList<std::pair<int, int>> result;
    if ((layout.fileSize <= 0) || (layout.pieceLength <= 0))
        return result;

    QSet<int> planned;
    const auto add = [&](const int piece, const int deadline)
    {
        if (planned.contains(piece))
            return;
        planned.insert(piece);
        if (!have(piece))
            result.append({piece, deadline});
    };

    // the window from the position
    const qint64 start = std::clamp<qint64>(position, 0, layout.fileSize - 1);
    const qint64 end = std::min(layout.fileSize, start + windowBytes(mode, bytesPerSecond)) - 1;
    const int firstWindowPiece = pieceOf(layout, start);
    const int lastWindowPiece = pieceOf(layout, end);
    for (int piece = firstWindowPiece; piece <= lastWindowPiece; ++piece)
        add(piece, (piece - firstWindowPiece) * DEADLINE_STEP_MS);

    // the container header
    const int lastHeadPiece = pieceOf(layout, std::min(layout.fileSize, HEAD_BYTES) - 1);
    for (int piece = pieceOf(layout, 0); piece <= lastHeadPiece; ++piece)
        add(piece, HEAD_DEADLINE_MS + ((piece - layout.firstPiece) * DEADLINE_STEP_MS));

    // the index at the end
    const qint64 tailBytes = std::min(layout.fileSize, std::clamp<qint64>(layout.fileSize / 50, MiB, 32 * MiB));
    const int firstTailPiece = pieceOf(layout, layout.fileSize - tailBytes);
    const int last = lastPiece(layout);
    for (int piece = last; piece >= firstTailPiece; --piece)
        add(piece, TAIL_DEADLINE_MS + ((last - piece) * DEADLINE_STEP_MS));

    return result;
}

bool StreamPlanner::needsReplan(const StreamLayout &layout, const qint64 plannedPosition, const qint64 newPosition
        , const StreamMode mode, const qint64 bytesPerSecond)
{
    Q_UNUSED(layout);
    if (newPosition < plannedPosition)
        return true;
    return (newPosition - plannedPosition) > (windowBytes(mode, bytesPerSecond) / 4);
}
