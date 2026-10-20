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

#include "qmlgui/backend/jacredsearch.h"

using namespace Qt::Literals::StringLiterals;

class TestJacRed final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestJacRed)

public:
    TestJacRed() = default;

private:
    // two films, one series, one without a magnet (skipped), one cartoon
    static QByteArray sample()
    {
        return
            "["
            "{\"tracker\":\"rutracker\",\"url\":\"https://rutracker.net/forum/viewtopic.php?t=1\",\"title\":\"Sintel (2010) 4K\",\"size\":5486820720,"
            "\"createTime\":\"2021-01-24T13:30:00\",\"sid\":4,\"pir\":1,\"magnet\":\"magnet:?xt=urn:btih:C334138EF5BFC2D568EA7324E0E2A3A7EC229BDD\",\"types\":[\"movie\"]},"
            "{\"tracker\":\"rutor\",\"url\":\"http://rutor.info/torrent/2\",\"title\":\"Tears of Steel 1080p\",\"size\":1200000000,"
            "\"createTime\":\"2022-03-01T00:00:00\",\"sid\":12,\"pir\":3,\"magnet\":\"magnet:?xt=urn:btih:AAAA\",\"types\":[\"movie\"]},"
            "{\"tracker\":\"kinozal\",\"url\":\"https://kinozal.tv/details.php?id=3\",\"title\":\"Severance S02\",\"size\":30000000000,"
            "\"createTime\":\"2025-01-17T10:00:00\",\"sid\":250,\"pir\":40,\"magnet\":\"magnet:?xt=urn:btih:BBBB\",\"types\":[\"serial\"]},"
            "{\"tracker\":\"nnmclub\",\"url\":\"https://nnmclub.to/4\",\"title\":\"No magnet\",\"size\":1,\"sid\":1,\"pir\":1,\"types\":[\"movie\"]},"
            "{\"tracker\":\"megapeer\",\"url\":\"https://megapeer.vip/5\",\"title\":\"Big Buck Bunny\",\"size\":700000000,"
            "\"createTime\":\"2020-05-05T00:00:00\",\"sid\":7,\"pir\":0,\"magnet\":\"magnet:?xt=urn:btih:CCCC\",\"types\":[\"multfilm\"]}"
            "]";
    }

private slots:
    void parsesEverything()
    {
        const QList<SearchResult> all = JacRedSearch::parse(sample(), u"all"_s, u"https://jac.red"_s);
        QCOMPARE(all.size(), 4);  // the one without a magnet is left out

        const SearchResult &first = all.first();
        QCOMPARE(first.fileName, u"Sintel (2010) 4K"_s);
        QVERIFY(first.fileUrl.startsWith(u"magnet:"));
        QCOMPARE(first.fileSize, 5486820720LL);
        QCOMPARE(first.nbSeeders, 4LL);
        QCOMPARE(first.nbLeechers, 1LL);
        QCOMPARE(first.engineName, u"rutracker"_s);
        QCOMPARE(first.siteUrl, u"https://jac.red"_s);
        QCOMPARE(first.descrLink, u"https://rutracker.net/forum/viewtopic.php?t=1"_s);
        QCOMPARE(first.pubDate.date(), QDate(2021, 1, 24));
    }

    void keepsToCategory()
    {
        QCOMPARE(JacRedSearch::parse(sample(), u"movies"_s, {}).size(), 3);  // films and the cartoon
        const QList<SearchResult> tv = JacRedSearch::parse(sample(), u"tv"_s, {});
        QCOMPARE(tv.size(), 1);
        QCOMPARE(tv.first().fileName, u"Severance S02"_s);
        QCOMPARE(JacRedSearch::parse(sample(), u"anime"_s, {}).size(), 0);
    }

    void coversVideoCategoriesOnly()
    {
        QVERIFY(JacRedSearch::covers(u"all"_s));
        QVERIFY(JacRedSearch::covers({}));
        QVERIFY(JacRedSearch::covers(u"movies"_s));
        QVERIFY(JacRedSearch::covers(u"tv"_s));
        QVERIFY(!JacRedSearch::covers(u"software"_s));
        QVERIFY(!JacRedSearch::covers(u"games"_s));
    }

    void badAnswerIsEmpty()
    {
        QVERIFY(JacRedSearch::parse("<html>blocked</html>", u"all"_s, {}).isEmpty());
        QVERIFY(JacRedSearch::parse("{}", u"all"_s, {}).isEmpty());
    }
};

QTEST_APPLESS_MAIN(TestJacRed)
#include "testjacred.moc"
