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
#include <QTest>

#include "qmlgui/streaming/httprange.h"

class TestHttpRange final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestHttpRange)

public:
    TestHttpRange() = default;

private slots:
    void parse_data()
    {
        QTest::addColumn<QByteArray>("header");
        QTest::addColumn<bool>("present");
        QTest::addColumn<bool>("satisfiable");
        QTest::addColumn<qint64>("start");
        QTest::addColumn<qint64>("end");

        // a 1000-byte resource
        QTest::newRow("no header") << QByteArray() << false << true << qint64(0) << qint64(999);
        QTest::newRow("closed") << QByteArray("bytes=100-199") << true << true << qint64(100) << qint64(199);
        QTest::newRow("open") << QByteArray("bytes=900-") << true << true << qint64(900) << qint64(999);
        QTest::newRow("suffix") << QByteArray("bytes=-100") << true << true << qint64(900) << qint64(999);
        QTest::newRow("suffix longer than file") << QByteArray("bytes=-5000") << true << true << qint64(0) << qint64(999);
        QTest::newRow("end past size is clamped") << QByteArray("bytes=500-5000") << true << true << qint64(500) << qint64(999);
        QTest::newRow("first of several") << QByteArray("bytes=0-9, 20-29") << true << true << qint64(0) << qint64(9);
        QTest::newRow("start past size") << QByteArray("bytes=1000-") << true << false << qint64(1000) << qint64(999);
        QTest::newRow("empty suffix") << QByteArray("bytes=-0") << true << false << qint64(0) << qint64(-1);
        QTest::newRow("reversed is ignored") << QByteArray("bytes=200-100") << false << true << qint64(0) << qint64(999);
        QTest::newRow("other unit is ignored") << QByteArray("items=0-5") << false << true << qint64(0) << qint64(999);
        QTest::newRow("garbage is ignored") << QByteArray("bytes=abc") << false << true << qint64(0) << qint64(999);
        QTest::newRow("spaces") << QByteArray("  bytes= 10 - 19 ") << true << true << qint64(10) << qint64(19);
    }

    void parse()
    {
        QFETCH(QByteArray, header);
        QFETCH(bool, present);
        QFETCH(bool, satisfiable);
        QFETCH(qint64, start);
        QFETCH(qint64, end);

        const HttpRange r = parseHttpRange(header, 1000);
        QCOMPARE(r.present, present);
        QCOMPARE(r.satisfiable, satisfiable);
        if (satisfiable)
        {
            QCOMPARE(r.start, start);
            QCOMPARE(r.end, end);
        }
    }
};

QTEST_APPLESS_MAIN(TestHttpRange)
#include "testhttprange.moc"
