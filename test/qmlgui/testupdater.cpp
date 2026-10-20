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

#include "qmlgui/backend/updater.h"

using namespace Qt::Literals::StringLiterals;

class TestUpdater final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestUpdater)

public:
    TestUpdater() = default;

private:
    static QByteArray release(const QByteArray &tag, const QByteArray &assets, const bool prerelease = false)
    {
        return "{\"tag_name\":\"" + tag + "\",\"name\":\"Flux " + tag + "\","
            "\"html_url\":\"https://github.com/o/r/releases/tag/" + tag + "\","
            "\"body\":\"- faster\",\"draft\":false,\"prerelease\":" + (prerelease ? "true" : "false") + ","
            "\"assets\":[" + assets + "]}";
    }

    static QByteArray asset(const QByteArray &name, const qint64 size)
    {
        return "{\"name\":\"" + name + "\",\"size\":" + QByteArray::number(size)
            + ",\"browser_download_url\":\"https://github.com/o/r/releases/download/x/" + name + "\"}";
    }

private slots:
    void compareVersions_data()
    {
        QTest::addColumn<QString>("a");
        QTest::addColumn<QString>("b");
        QTest::addColumn<int>("sign");

        QTest::newRow("equal") << u"0.1.0"_s << u"0.1.0"_s << 0;
        QTest::newRow("v prefix") << u"v0.2.0"_s << u"0.2.0"_s << 0;
        QTest::newRow("trailing zero") << u"1.0"_s << u"1.0.0"_s << 0;
        QTest::newRow("newer patch") << u"0.1.1"_s << u"0.1.0"_s << 1;
        QTest::newRow("numeric, not text") << u"1.2.10"_s << u"1.2.9"_s << 1;
        QTest::newRow("older minor") << u"0.1.9"_s << u"0.2.0"_s << -1;
        QTest::newRow("pre-release first") << u"1.0.0-beta"_s << u"1.0.0"_s << -1;
        QTest::newRow("release after beta") << u"v1.0.0"_s << u"1.0.0-rc.1"_s << 1;
        QTest::newRow("beta order") << u"1.0.0-beta.2"_s << u"1.0.0-beta.1"_s << 1;
    }

    void compareVersions()
    {
        QFETCH(QString, a);
        QFETCH(QString, b);
        QFETCH(int, sign);
        const int result = Updater::compareVersions(a, b);
        QCOMPARE((result > 0) - (result < 0), sign);
        QCOMPARE(-((Updater::compareVersions(b, a) > 0) - (Updater::compareVersions(b, a) < 0)), sign);
    }

    void parsesARelease()
    {
        const QVariantMap r = Updater::parseRelease(release("v0.2.0", asset("Flux-0.2.0-win64.zip", 50) + "," + asset("Flux-0.2.0-setup.exe", 40)));
        QCOMPARE(r.value(u"version"_s).toString(), u"v0.2.0"_s);
        QCOMPARE(r.value(u"name"_s).toString(), u"Flux v0.2.0"_s);
        QCOMPARE(r.value(u"url"_s).toString(), u"https://github.com/o/r/releases/tag/v0.2.0"_s);
        QCOMPARE(r.value(u"notes"_s).toString(), u"- faster"_s);
        QCOMPARE(r.value(u"downloadName"_s).toString(), u"Flux-0.2.0-setup.exe"_s);  // the installer before the archive
        QCOMPARE(r.value(u"downloadSize"_s).toLongLong(), 40LL);
        QVERIFY(r.value(u"downloadUrl"_s).toString().endsWith(u"Flux-0.2.0-setup.exe"));
        QVERIFY(!r.value(u"prerelease"_s).toBool());
    }

    void archiveWhenNoInstaller()
    {
        const QVariantMap r = Updater::parseRelease(release("v0.2.0", asset("notes.txt", 1) + "," + asset("Flux-0.2.0-win64.zip", 50)));
        QCOMPARE(r.value(u"downloadName"_s).toString(), u"Flux-0.2.0-win64.zip"_s);
    }

    void noAssetsMeansThePage()
    {
        const QVariantMap r = Updater::parseRelease(release("v0.3.0", ""));
        QVERIFY(r.value(u"downloadUrl"_s).toString().isEmpty());
        QVERIFY(!r.value(u"url"_s).toString().isEmpty());
    }

    void prereleaseIsMarked()
    {
        QVERIFY(Updater::parseRelease(release("v0.4.0-beta", "", true)).value(u"prerelease"_s).toBool());
    }

    void notAReleaseIsEmpty()
    {
        QVERIFY(Updater::parseRelease("{\"message\":\"Not Found\"}").isEmpty());
        QVERIFY(Updater::parseRelease("<html></html>").isEmpty());
    }
};

QTEST_APPLESS_MAIN(TestUpdater)
#include "testupdater.moc"
