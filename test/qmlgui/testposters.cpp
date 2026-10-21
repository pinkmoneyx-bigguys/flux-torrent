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

#include "qmlgui/backend/filmdetails.h"
#include "qmlgui/backend/posters.h"
#include "qmlgui/backend/searchresults.h"

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

    void pipesAndLeadingTags()
    {
        // "Original | Local [year, …]" and a tag before the titles
        const FilmInfo a = FilmInfo::parse(u"Cyberpunk: Edgerunners | Киберпанк: Бегущие по краю [2022, Web, 10 эп.] WebRip 1080p raw"_s);
        QCOMPARE(a.title, u"Cyberpunk: Edgerunners"_s);
        QCOMPARE(a.original, u"Cyberpunk: Edgerunners"_s);
        QCOMPARE(a.year, 2022);
        const FilmInfo b = FilmInfo::parse(u"[sub] Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [2022, приключения, фантастика]"_s);
        QCOMPARE(b.title, u"Киберпанк: Бегущие по краю"_s);
        QCOMPARE(b.original, u"Cyberpunk: Edgerunners"_s);
        QCOMPARE(a.key, b.key);
        // the voice-overs after the brackets stay out of the titles
        const FilmInfo c = FilmInfo::parse(u"Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [S01] (2022) WEB-DL 1080p | D | Flarrow Films"_s);
        QCOMPARE(c.key, a.key);
    }

    void whatTheSourceKnowsComesFirst()
    {
        ReleaseMeta meta;
        meta.title = u"Киберпанк: Бегущие по краю"_s;
        meta.original = u"Cyberpunk: Edgerunners"_s;
        meta.year = 2022;
        meta.seasons = {2};
        // a name the parser can't read the original title from
        const FilmInfo f = SearchResultsFilter::filmOfRelease(u"Киберпанк: Бегушие по краю (Cyberpunk: Edgerunners) Сезон 2 Серии 01-10 (HD1080p WEBRip)"_s, meta);
        QCOMPARE(f.original, u"Cyberpunk: Edgerunners"_s);
        QCOMPARE(f.year, 2022);
        QVERIFY(f.series);
        QCOMPARE(f.key, FilmInfo::parse(u"Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [2022]"_s).key);

        // what a source sometimes gets wrong: the whole name as the original title, the titles swapped
        ReleaseMeta junk;
        junk.title = u"Киберпанк: Бегушие по краю"_s;
        junk.original = u"Киберпанк: Бегушие по краю / Cyberpunk: Edgerunners [ONA] [10 из 10] [2022, WEB-DL] [1080p]"_s;
        junk.year = 2022;
        QCOMPARE(SearchResultsFilter::filmOfRelease(u"Киберпанк: Бегушие по краю / Cyberpunk: Edgerunners [ONA] [10 из 10] [2022, WEB-DL] [1080p]"_s, junk).key, f.key);
        ReleaseMeta swapped;
        swapped.title = u"Cyberpunk: Edgerunners"_s;
        swapped.original = u"Киберпанк: Бегушие по краю"_s;
        swapped.year = 2022;
        const FilmInfo s = SearchResultsFilter::filmOfRelease(u"Cyberpunk: Edgerunners | Киберпанк: Бегушие по краю [2022, TV]"_s, swapped);
        QCOMPARE(s.title, u"Киберпанк: Бегушие по краю"_s);
        QCOMPARE(s.key, f.key);
    }

    void titlesHaveTheQuery()
    {
        const auto match = [](const QString &name, const QString &query)
        {
            return SearchResultsFilter::titlesMatch(name, {}, query);
        };
        // the genres in brackets don't count
        QVERIFY(!match(u"Эксперименты Лэйн / Serial Experiments Lain [1998, аниме, киберпанк, BDRip]"_s, u"киберпанк"_s));
        QVERIFY(match(u"Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [S01] (2022) WEB-DL"_s, u"киберпанк"_s));
        // a word's other ending, a title spelled a little differently, short words left aside
        QVERIFY(match(u"Киберпанк: Бегущие по краю [2022]"_s, u"киберпанка"_s));
        QVERIFY(match(u"Киберпанк: Бегушие по краю [2022]"_s, u"Киберпанк Бегущие по краю"_s));
        QVERIFY(match(u"Kubuntu 24.04"_s, u"ubuntu"_s));
        QVERIFY(!match(u"Дюна: Часть вторая [2024]"_s, u"киберпанк 2"_s));
        // what the source knows of the titles counts too
        ReleaseMeta meta;
        meta.title = u"Киберпанк: Бегущие по краю"_s;
        QVERIFY(SearchResultsFilter::titlesMatch(u"Cyberpunk.Edgerunners.S01.1080p"_s, meta, u"киберпанк"_s));
        // but not a source's "title" that is the whole name with the genres
        ReleaseMeta junk;
        junk.title = u"Эксперименты Лэйн"_s;
        junk.original = u"Эксперименты Лэйн / Serial Experiments Lain [TV] [13 из 13] [1998, киберпанк, фантастика, драма, BDRemux]"_s;
        QVERIFY(!SearchResultsFilter::titlesMatch(junk.original, junk, u"киберпанк"_s));
        // nothing to look for: everything
        QVERIFY(match(u"Anything"_s, u"x"_s));
    }

    void releaseTags()
    {
        const auto tags = [](const QString &name, const ReleaseMeta &meta = {})
        {
            QStringList list;
            for (const QVariant &tag : SearchResultsFilter::tagsOf(name, meta))
                list.append(tag.toMap().value(u"kind"_s).toString() + u':' + tag.toMap().value(u"text"_s).toString());
            return list;
        };
        QCOMPARE(tags(u"Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [S01] (2022) BDRip-HEVC 1080p | D, P, L | Flarrow Films, LostFilm"_s),
                 QStringList({u"quality:1080p"_s, u"source:BDRip"_s, u"codec:HEVC"_s, u"season:1"_s, u"audio:dub"_s, u"audio:pro"_s, u"audio:amateur"_s}));
        QCOMPARE(tags(u"Разделение / Severance / Сезон: 2 / Серии: 1-10 из 10 [2025, США, WEB-DL 2160p, HDR10, Dolby Vision] MVO + Sub"_s),
                 QStringList({u"quality:4K"_s, u"hdr:Dolby Vision"_s, u"source:WEB-DL"_s, u"season:2"_s, u"episodes:1–10/10"_s, u"audio:mvo"_s, u"audio:sub"_s}));
        ReleaseMeta hdr;
        hdr.video = u"hdr"_s;
        hdr.seasons = {1, 2, 3};
        QCOMPARE(tags(u"Something 1080p"_s, hdr), QStringList({u"quality:1080p"_s, u"hdr:HDR"_s, u"season:1–3"_s}));
        QVERIFY(tags(u"Big Buck Bunny"_s).isEmpty());
        QCOMPARE(tags(u"Something 2 xMVO (LostFilm) + AVO"_s), QStringList({u"audio:mvo"_s, u"audio:avo"_s}));

        // a source's "Дубляж" is a kind of voice-over, not a studio
        ReleaseMeta voices;
        voices.voices = {u"LostFilm"_s, u"Дубляж"_s, u"Субтитры"_s};
        QCOMPARE(tags(u"Something"_s, voices), QStringList({u"audio:dub"_s, u"audio:sub"_s}));
        QCOMPARE(SearchResultsFilter::studiosOf(voices.voices), QStringList({u"LostFilm"_s}));
    }

    void findsTheArticle()
    {
        const QByteArray search =
            "{\"query\":{\"pages\":["
            "{\"index\":2,\"title\":\"Rebecca (Cyberpunk: Edgerunners)\",\"description\":\"Cyberpunk 2077 character\"},"
            "{\"index\":1,\"title\":\"Cyberpunk: Edgerunners\",\"description\":\"2022 anime series\"},"
            "{\"index\":3,\"title\":\"Cyberpunk: Edgerunners 2\",\"description\":\"2026 anime series\"}]}}";
        QCOMPARE(FilmDetails::pickArticle(search, u"Cyberpunk: Edgerunners"_s, 2022, true), u"Cyberpunk: Edgerunners"_s);
        const QByteArray book = "{\"query\":{\"pages\":[{\"index\":1,\"title\":\"Dune\",\"description\":\"1965 novel by Frank Herbert\"}]}}";
        QVERIFY(FilmDetails::pickArticle(book, u"Dune"_s, 2021, false).isEmpty());
        const QByteArray films = QString(
            u"{\"query\":{\"pages\":["
            "{\"index\":1,\"title\":\"Дюна (фильм, 1984)\",\"description\":\"фильм Дэвида Линча\"},"
            "{\"index\":2,\"title\":\"Дюна (фильм, 2021)\",\"description\":\"фильм Дени Вильнёва\"}]}}"_s).toUtf8();
        QCOMPARE(FilmDetails::pickArticle(films, u"Дюна"_s, 2021, false), u"Дюна (фильм, 2021)"_s);
    }

    void readsTheArticle()
    {
        const QByteArray json = QString(
            u"{\"query\":{\"pages\":[{\"title\":\"Cyberpunk: Edgerunners\",\"extract\":\"An anime series.\\n\\nIt premiered in 2022.\","
            "\"fullurl\":\"https://en.wikipedia.org/wiki/Cyberpunk:_Edgerunners\","
            "\"original\":{\"source\":\"https://upload.example/poster.jpg\",\"width\":250,\"height\":375},"
            "\"langlinks\":[{\"lang\":\"uk\",\"title\":\"Кіберпанк: Бігуни краєм\"}]}]}}"_s).toUtf8();
        const QVariantMap article = FilmDetails::readArticle(json);
        QCOMPARE(article.value(u"url"_s).toString(), u"https://en.wikipedia.org/wiki/Cyberpunk:_Edgerunners"_s);
        QCOMPARE(article.value(u"langlink"_s).toString(), u"Кіберпанк: Бігуни краєм"_s);
        QVERIFY(article.value(u"portrait"_s).toBool());
        QVERIFY(FilmDetails::readArticle("{\"query\":{\"pages\":[{\"title\":\"X\",\"missing\":true}]}}").isEmpty());

        QCOMPARE(FilmDetails::shorten(u"One.\n\n\nTwo."_s), u"One.\nTwo."_s);
        const QString longText = u"First sentence here. "_s.repeated(60);
        const QString cut = FilmDetails::shorten(longText, 100);
        QVERIFY(cut.size() <= 100);
        QVERIFY(cut.endsWith(u'.'));
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
