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

#include "qmlgui/backend/posters.h"

using namespace Qt::Literals::StringLiterals;

class TestPosters final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestPosters)

public:
    TestPosters() = default;

private slots:
    void trackerStyleNames()
    {
        const FilmInfo f = FilmInfo::parse(u"Интерстеллар / Interstellar (Кристофер Нолан / Christopher Nolan) [2014, США, фантастика, BDRip 1080p] Dub + Original"_s);
        QCOMPARE(f.title, u"Интерстеллар"_s);
        QCOMPARE(f.original, u"Interstellar"_s);
        QCOMPARE(f.year, 2014);
        QCOMPARE(f.quality, u"1080p"_s);
        QVERIFY(!f.series);
    }

    void rutorStyleYearInBrackets()
    {
        const FilmInfo f = FilmInfo::parse(u"Интерстеллар / Interstellar (2014) UHD BDRip 2160p от селезень"_s);
        QCOMPARE(f.original, u"Interstellar"_s);
        QCOMPARE(f.year, 2014);
        QCOMPARE(f.quality, u"2160p"_s);
    }

    void seriesNotesAreNotTitles()
    {
        const FilmInfo f = FilmInfo::parse(u"Разделение / Severance / Сезон: 2 / Серии: 1-10 из 10 [2025, США, WEB-DL 1080p]"_s);
        QCOMPARE(f.title, u"Разделение"_s);
        QCOMPARE(f.original, u"Severance"_s);
        QCOMPARE(f.year, 2025);
        QVERIFY(f.series);
    }

    void tagsAfterTheTitle()
    {
        const FilmInfo f = FilmInfo::parse(u"Интерстеллар / Interstellar BDRip 720p"_s);
        QCOMPARE(f.original, u"Interstellar"_s);
        QCOMPARE(f.quality, u"720p"_s);
    }

    void sceneNames()
    {
        const FilmInfo f = FilmInfo::parse(u"Interstellar.2014.1080p.BluRay.x264-SPARKS"_s);
        QCOMPARE(f.title, u"Interstellar"_s);
        QCOMPARE(f.original, u"Interstellar"_s);
        QCOMPARE(f.year, 2014);
        QCOMPARE(f.quality, u"1080p"_s);
    }

    void releasesOfOneFilmShareAKey()
    {
        const QString a = FilmInfo::parse(u"Интерстеллар / Interstellar (Кристофер Нолан) [2014, BDRip 1080p]"_s).key;
        const QString b = FilmInfo::parse(u"Интерстеллар / Interstellar (2014) UHD BDRip 2160p"_s).key;
        const QString c = FilmInfo::parse(u"Interstellar.2014.2160p.UHD.BluRay"_s).key;
        QCOMPARE(a, b);
        QCOMPARE(a, c);
        QVERIFY(a != FilmInfo::parse(u"Interstellar (1971) TVRip"_s).key);
    }

    void picksThePosterOfThatYear()
    {
        const QByteArray json =
            "{\"d\":["
            "{\"i\":{\"imageUrl\":\"https://m.media-amazon.com/images/M/other._V1_.jpg\"},\"l\":\"Interstellar Wars\",\"qid\":\"movie\",\"y\":2016},"
            "{\"i\":{\"imageUrl\":\"https://m.media-amazon.com/images/M/right._V1_.jpg\"},\"l\":\"Interstellar\",\"qid\":\"movie\",\"y\":2014},"
            "{\"l\":\"Interstellar\",\"qid\":\"movie\",\"y\":2014},"
            "{\"i\":{\"imageUrl\":\"https://m.media-amazon.com/images/M/person._V1_.jpg\"},\"l\":\"Someone\",\"qid\":\"\",\"y\":0}"
            "]}";
        QCOMPARE(Posters::pickImdb(json, u"Interstellar"_s, 2014, false), u"https://m.media-amazon.com/images/M/right._V1_SX300.jpg"_s);
        QCOMPARE(Posters::pickImdb(json, u"Interstellar"_s, 0, false), u"https://m.media-amazon.com/images/M/right._V1_SX300.jpg"_s);
        QVERIFY(Posters::pickImdb(json, u"Interstellar"_s, 1990, false).isEmpty());  // nothing of that year
        QVERIFY(Posters::pickImdb("not json", u"Interstellar"_s, 2014, false).isEmpty());
    }

    void imdbNeedsTheSameNameOrTheExactYear()
    {
        const QByteArray json =
            "{\"d\":["
            "{\"i\":{\"imageUrl\":\"https://m.media-amazon.com/images/M/wars._V1_.jpg\"},\"l\":\"Star Wars: The Clone Wars\",\"qid\":\"tvSeries\",\"y\":2008},"
            "{\"i\":{\"imageUrl\":\"https://m.media-amazon.com/images/M/ftl._V1_.jpg\"},\"l\":\"Faster Than Light: The Dream of Interstellar Flight\",\"qid\":\"movie\",\"y\":2017}"
            "]}";
        // punctuation and case don't matter
        QCOMPARE(Posters::pickImdb(json, u"Faster Than Light. the dream of interstellar flight"_s, 0, false),
            u"https://m.media-amazon.com/images/M/ftl._V1_SX300.jpg"_s);
        // another name: not without a year to check
        QVERIFY(Posters::pickImdb(json, u"Межзвёздные войны"_s, 0, false).isEmpty());
        QVERIFY(Posters::pickImdb(json, u"Межзвёздные войны"_s, 2016, false).isEmpty());
        // a Russian title IMDb found by: its year must be the one
        QCOMPARE(Posters::pickImdb(json, {}, 2017, false), u"https://m.media-amazon.com/images/M/ftl._V1_SX300.jpg"_s);
    }

    void wikipediaPosters()
    {
        const QByteArray json = QByteArray(
            "{\"query\":{\"pages\":["
            "{\"title\":\"Нолан, Кристофер\",\"index\":2,\"description\":\"режиссёр\","
            "\"thumbnail\":{\"source\":\"https://thumb.wikimedia.org/nolan.jpg\",\"width\":300,\"height\":450}},"
            "{\"title\":\"Интерстеллар (саундтрек)\",\"index\":3,\"description\":\"альбом 2014 года\","
            "\"thumbnail\":{\"source\":\"https://thumb.wikimedia.org/album.jpg\",\"width\":300,\"height\":450}},"
            "{\"title\":\"Интерстеллар\",\"index\":1,\"description\":\"фильм Кристофера Нолана 2014 года\","
            "\"thumbnail\":{\"source\":\"https://thumb.wikimedia.org/poster.jpg\",\"width\":300,\"height\":418}}"
            "]}}");
        QCOMPARE(Posters::pickWikipedia(json, u"Интерстеллар"_s, 2014, false), u"https://thumb.wikimedia.org/poster.jpg"_s);
        QVERIFY(Posters::pickWikipedia(json, u"Интерстеллар"_s, 1990, false).isEmpty());   // another year
        QVERIFY(Posters::pickWikipedia(json, u"Межзвёздные войны"_s, 2014, false).isEmpty());  // another name

        // a still (wider than tall) is no poster
        const QByteArray still =
            "{\"query\":{\"pages\":[{\"title\":\"Interstellar (film)\",\"index\":1,\"description\":\"2014 film by Christopher Nolan\","
            "\"thumbnail\":{\"source\":\"https://thumb.wikimedia.org/still.jpg\",\"width\":300,\"height\":160}}]}}";
        QVERIFY(Posters::pickWikipedia(still, u"Interstellar"_s, 2014, false).isEmpty());
    }

    void shikimoriPosters()
    {
        const QByteArray json = QByteArray(
            "[{\"name\":\"Naruto\",\"russian\":\"Наруто\",\"aired_on\":\"2002-10-03\",\"image\":{\"original\":\"/system/animes/original/20.jpg?1\"}},"
            "{\"name\":\"Boruto\",\"russian\":\"Боруто\",\"aired_on\":\"2017-04-05\",\"image\":{\"original\":\"/assets/globals/missing_original.jpg\"}}]");
        QCOMPARE(Posters::pickShikimori(json, u"Наруто"_s, 2002), u"https://shikimori.io/system/animes/original/20.jpg?1"_s);
        QCOMPARE(Posters::pickShikimori(json, u"naruto"_s, 0), u"https://shikimori.io/system/animes/original/20.jpg?1"_s);
        QVERIFY(Posters::pickShikimori(json, u"Наруто"_s, 2015).isEmpty());
        QVERIFY(Posters::pickShikimori(json, u"Боруто"_s, 2017).isEmpty());  // no picture
    }
};

QTEST_APPLESS_MAIN(TestPosters)
#include "testposters.moc"
