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

#include "base/bittorrent/sessionstatus.h"
#include "qmlgui/backend/sessionfacade.h"

class TestSessionFacade final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestSessionFacade)

public:
    TestSessionFacade() = default;

private slots:
    void snapshotMapsRates() const
    {
        BitTorrent::SessionStatus st {};
        st.payloadDownloadRate = 1000;
        st.payloadUploadRate = 200;
        st.dhtNodes = 412;
        st.hasIncomingConnections = false;

        const SessionSnapshot s = SessionFacade::makeSnapshot(st, 8, 4);
        QCOMPARE(s.downloadRate, 1000);
        QCOMPARE(s.uploadRate, 200);
        QCOMPARE(s.dhtNodes, 412);
        QCOMPARE(s.torrentCount, 8);
        QCOMPARE(s.activeCount, 4);
        QVERIFY(s.connected);
    }

    void snapshotMapsTotals() const
    {
        BitTorrent::SessionStatus st {};
        st.allTimeDownload = 5'000'000'000;
        st.allTimeUpload = 7'000'000'000;

        const SessionSnapshot s = SessionFacade::makeSnapshot(st, 0, 0);
        QCOMPARE(s.totalDownloaded, qint64(5'000'000'000));
        QCOMPARE(s.totalUploaded, qint64(7'000'000'000));
    }

    void snapshotDisconnected() const
    {
        BitTorrent::SessionStatus st {};
        st.dhtNodes = 0;
        st.hasIncomingConnections = false;
        QVERIFY(!SessionFacade::makeSnapshot(st, 0, 0).connected);
    }

    void snapshotConnectedByIncoming() const
    {
        BitTorrent::SessionStatus st {};
        st.dhtNodes = 0;
        st.hasIncomingConnections = true;
        QVERIFY(SessionFacade::makeSnapshot(st, 0, 0).connected);
    }
};

QTEST_APPLESS_MAIN(TestSessionFacade)
#include "testsessionfacade.moc"
