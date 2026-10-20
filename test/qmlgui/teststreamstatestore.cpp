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
#include <QTimeZone>
#include <QTest>

#include "base/global.h"
#include "qmlgui/streaming/streamstatestore.h"

class TestStreamStateStore final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestStreamStateStore)

public:
    TestStreamStateStore() = default;

private:
    static StreamRecord record(const QString &id, const int file, const bool stopped)
    {
        StreamRecord r;
        r.torrentId = id;
        r.fileIndex = file;
        r.wasStopped = stopped;
        r.openedAt = QDateTime::fromSecsSinceEpoch(1'790'000'000, QTimeZone::UTC);
        return r;
    }

private slots:
    void roundTrip()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"sub/streams.json"_s);
        {
            StreamStateStore store {path};
            QVERIFY(store.add(record(u"aa"_s, 0, true)));
            QVERIFY(store.add(record(u"bb"_s, 2, false)));
        }
        StreamStateStore reopened {path};
        QCOMPARE(reopened.records().size(), 2);
        QCOMPARE(reopened.records().at(0), record(u"aa"_s, 0, true));
        QCOMPARE(reopened.records().at(1), record(u"bb"_s, 2, false));
    }

    void addReplacesSameStream()
    {
        QTemporaryDir dir;
        StreamStateStore store {dir.filePath(u"streams.json"_s)};
        store.add(record(u"aa"_s, 0, true));
        store.add(record(u"aa"_s, 0, false));
        QCOMPARE(store.records().size(), 1);
        QCOMPARE(store.records().first().wasStopped, false);
    }

    void removeDeletes()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"streams.json"_s);
        StreamStateStore store {path};
        store.add(record(u"aa"_s, 0, true));
        store.add(record(u"aa"_s, 1, true));
        QVERIFY(store.remove(u"aa"_s, 0));
        QCOMPARE(StreamStateStore(path).records().size(), 1);
        QVERIFY(store.remove(u"aa"_s, 1));
        QVERIFY2(!QFile::exists(path), "no open streams, no file");
    }

    void corruptFileIsIgnored()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"streams.json"_s);
        QFile file {path};
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write("{ not json");
        file.close();
        StreamStateStore store {path};
        QVERIFY(store.records().isEmpty());
        QVERIFY(store.add(record(u"aa"_s, 0, true)));
        QCOMPARE(StreamStateStore(path).records().size(), 1);
    }

    void restoreAllClears()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(u"streams.json"_s);
        {
            StreamStateStore store {path};
            store.add(record(u"aa"_s, 0, true));
            store.add(record(u"bb"_s, 1, false));
        }
        // a crash later: the next start finds both and rolls them back
        StreamStateStore store {path};
        QStringList restored;
        store.restoreAll([&restored](const StreamRecord &r) { restored.append(r.torrentId); });
        QCOMPARE(restored, (QStringList {u"aa"_s, u"bb"_s}));
        QVERIFY(store.records().isEmpty());
        QVERIFY(!QFile::exists(path));
    }
};

QTEST_APPLESS_MAIN(TestStreamStateStore)
#include "teststreamstatestore.moc"
