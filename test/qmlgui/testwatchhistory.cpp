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

#include <QFile>
#include <QObject>
#include <QTemporaryDir>
#include <QTest>

#include "base/global.h"
#include "qmlgui/backend/watchhistory.h"

class TestWatchHistory final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestWatchHistory)

public:
    TestWatchHistory() = default;

private slots:
    void roundTrip()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"watch-history.json"_s);
        {
            WatchHistory history {path};
            history.save(WatchHistory::keyOf(u"abc"_s, 2), 754.5, 1500);
            history.flush();
        }
        WatchHistory reopened {path};
        QCOMPARE(reopened.position(u"abc:2"_s), 754.5);
        QCOMPARE(reopened.duration(u"abc:2"_s), 1500.0);
        QCOMPARE(reopened.progress(u"abc:2"_s), 754.5 / 1500);
    }

    void writesAreBatchedAndFlushedOnDestruction()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"watch-history.json"_s);
        {
            WatchHistory history {path};
            history.save(u"k/0"_s, 100, 200);
            QVERIFY2(!QFile::exists(path), "not written on every position update");
        }
        QCOMPARE(WatchHistory(path).position(u"k/0"_s), 100.0);
    }

    void resumeRules()
    {
        WatchHistory history {QString()};
        history.save(u"a/0"_s, 12, 1000);
        QCOMPARE(history.resumePosition(u"a/0"_s), 0.0); // too early to bother
        history.save(u"a/0"_s, 400, 1000);
        QCOMPARE(history.resumePosition(u"a/0"_s), 400.0);
        history.save(u"a/0"_s, 990, 1000);
        QCOMPARE(history.resumePosition(u"a/0"_s), 0.0); // basically watched
        history.save(u"b/0"_s, 300, 0);
        QCOMPARE(history.resumePosition(u"b/0"_s), 300.0); // unknown duration: still resumable
        QCOMPARE(history.resumePosition(u"none/0"_s), 0.0);
    }

    void durationKeptWhenUnknown()
    {
        WatchHistory history {QString()};
        history.save(u"a/0"_s, 100, 1000);
        history.save(u"a/0"_s, 200, 0);
        QCOMPARE(history.duration(u"a/0"_s), 1000.0);
    }

    void clearForgets()
    {
        WatchHistory history {QString()};
        history.save(u"a/0"_s, 100, 1000);
        const int revision = history.revision();
        history.clear(u"a/0"_s);
        QCOMPARE(history.position(u"a/0"_s), 0.0);
        QVERIFY(history.revision() > revision);
    }

    void corruptFileIgnored()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"watch-history.json"_s);
        QFile file {path};
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("[[[ nope");
        file.close();
        WatchHistory history {path};
        QCOMPARE(history.position(u"x/0"_s), 0.0);
        history.save(u"x/0"_s, 50, 100);
        history.flush();
        QCOMPARE(WatchHistory(path).position(u"x/0"_s), 50.0);
    }
};

QTEST_GUILESS_MAIN(TestWatchHistory)
#include "testwatchhistory.moc"
