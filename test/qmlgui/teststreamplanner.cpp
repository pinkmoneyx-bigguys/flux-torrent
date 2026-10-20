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

#include <QObject>
#include <QSet>
#include <QTest>

#include "qmlgui/streaming/streamplanner.h"

namespace
{
    constexpr qint64 MiB = 1024 * 1024;

    // A 100 MiB file starting 1 MiB into piece 3 of a torrent with 1 MiB pieces
    StreamLayout layout()
    {
        StreamLayout l;
        l.fileSize = 100 * MiB;
        l.pieceLength = MiB;
        l.firstPiece = 3;
        l.firstPieceOffset = 512 * 1024;
        return l;
    }

    QList<int> piecesOf(const QList<std::pair<int, int>> &plan)
    {
        QList<int> pieces;
        for (const auto &[piece, deadline] : plan)
            pieces.append(piece);
        return pieces;
    }

    int deadlineOf(const QList<std::pair<int, int>> &plan, const int piece)
    {
        for (const auto &[p, deadline] : plan)
        {
            if (p == piece)
                return deadline;
        }
        return -1;
    }

    const auto haveNothing = [](int) { return false; };
}

class TestStreamPlanner final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestStreamPlanner)

public:
    TestStreamPlanner() = default;

private slots:
    void pieceOfOffset()
    {
        const StreamLayout l = layout();
        QCOMPARE(StreamPlanner::pieceOf(l, 0), 3);
        QCOMPARE(StreamPlanner::pieceOf(l, 512 * 1024 - 1), 3);
        QCOMPARE(StreamPlanner::pieceOf(l, 512 * 1024), 4);
        QCOMPARE(StreamPlanner::pieceOf(l, l.fileSize - 1), StreamPlanner::lastPiece(l));
        QCOMPARE(StreamPlanner::lastPiece(l), 3 + 100); // 0.5 MiB in piece 3, 99 full pieces, 0.5 MiB in piece 103
    }

    void headAndTailFirst()
    {
        const StreamLayout l = layout();
        const auto plan = StreamPlanner::plan(l, 0, StreamMode::Fast, 0, haveNothing);
        const QList<int> pieces = piecesOf(plan);
        QVERIFY2(pieces.contains(3), "the first piece of the file");
        QVERIFY2(pieces.contains(StreamPlanner::lastPiece(l)), "the last piece (MKV/MP4 index)");
        QCOMPARE(deadlineOf(plan, 3), 0);
        // tail of a 100 MiB file: 2 % = 2 MiB
        QVERIFY(pieces.contains(StreamPlanner::lastPiece(l) - 1));
        QVERIFY(deadlineOf(plan, StreamPlanner::lastPiece(l)) > deadlineOf(plan, 3));
        QCOMPARE(QSet<int>(pieces.cbegin(), pieces.cend()).size(), pieces.size()); // no duplicates
    }

    void windowFollowsPosition()
    {
        const StreamLayout l = layout();
        const qint64 position = 40 * MiB;
        const auto plan = StreamPlanner::plan(l, position, StreamMode::Fast, 0, haveNothing);
        const int first = StreamPlanner::pieceOf(l, position);
        QCOMPARE(deadlineOf(plan, first), 0);
        // deadlines grow along the window
        QVERIFY(deadlineOf(plan, first + 1) > deadlineOf(plan, first));
        QVERIFY(deadlineOf(plan, first + 10) > deadlineOf(plan, first + 1));
        // 16 MiB window in Fast mode
        QVERIFY(piecesOf(plan).contains(StreamPlanner::pieceOf(l, position + 16 * MiB - 1)));
        QVERIFY(!piecesOf(plan).contains(StreamPlanner::pieceOf(l, position + 20 * MiB)));
    }

    void seekMovesWindow()
    {
        const StreamLayout l = layout();
        const auto before = piecesOf(StreamPlanner::plan(l, 10 * MiB, StreamMode::Fast, 0, haveNothing));
        const auto after = piecesOf(StreamPlanner::plan(l, 70 * MiB, StreamMode::Fast, 0, haveNothing));
        QVERIFY(before.contains(StreamPlanner::pieceOf(l, 12 * MiB)));
        QVERIFY(!after.contains(StreamPlanner::pieceOf(l, 12 * MiB)));
        QVERIFY(after.contains(StreamPlanner::pieceOf(l, 72 * MiB)));
    }

    void skipsPiecesWeHave()
    {
        const StreamLayout l = layout();
        const auto have = [](const int piece) { return (piece % 2) == 0; };
        const auto plan = StreamPlanner::plan(l, 0, StreamMode::Fast, 0, have);
        for (const int piece : piecesOf(plan))
            QVERIFY2((piece % 2) == 1, "pieces already downloaded get no deadline");
    }

    void modesChangeWindow()
    {
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Fast, 0), 16 * MiB);
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Economy, 0), 8 * MiB);
        // Smooth: four minutes at the bitrate, 3 MiB/s when unknown, between 64 MiB and 1 GiB
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Smooth, 0), 720 * MiB);
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Smooth, MiB / 8), 64 * MiB);
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Smooth, 10 * MiB), 1024 * MiB);
        QCOMPARE(StreamPlanner::windowBytes(StreamMode::Smooth, MiB), 240 * MiB);
    }

    void windowStopsAtFileEnd()
    {
        const StreamLayout l = layout();
        const auto plan = StreamPlanner::plan(l, l.fileSize - MiB, StreamMode::Smooth, 0, haveNothing);
        for (const int piece : piecesOf(plan))
            QVERIFY(piece <= StreamPlanner::lastPiece(l));
    }

    void replanThreshold()
    {
        const StreamLayout l = layout();
        // Fast: 16 MiB window, replan after a quarter of it or any step back
        QVERIFY(!StreamPlanner::needsReplan(l, 10 * MiB, 10 * MiB + 3 * MiB, StreamMode::Fast, 0));
        QVERIFY(StreamPlanner::needsReplan(l, 10 * MiB, 10 * MiB + 5 * MiB, StreamMode::Fast, 0));
        QVERIFY(StreamPlanner::needsReplan(l, 10 * MiB, 5 * MiB, StreamMode::Fast, 0));
    }
};

QTEST_APPLESS_MAIN(TestStreamPlanner)
#include "teststreamplanner.moc"
