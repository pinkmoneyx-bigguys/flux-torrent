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

#include "posters.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUrl>

#include "base/global.h"
#include "base/net/downloadmanager.h"
#include "medialibrary.h"

namespace
{
    const int PARALLEL = 4;
    const QString USER_AGENT = u"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Flux"_s;

    bool hasLatin(const QString &text)
    {
        static const QRegularExpression latin {u"[A-Za-z]"_s};
        return text.contains(latin);
    }

    // a title without the release tags that can follow it ("Interstellar BDRip 720p" → "Interstellar")
    QString withoutTags(const QString &part)
    {
        static const QRegularExpression tags {
            u"\\s+(2160p|4K|UHD|1080[pi]|720p|576p|480p|WEB[- ]?DL|WEB[- ]?Rip|BluRay|BDRip|BRRip|HDRip|DVDRip|HDTV|TVRip|SATRip|REMUX|HEVC|x26[45]|H\\.?26[45])\\b.*$"_s,
            QRegularExpression::CaseInsensitiveOption};
        QString t = part;
        t.remove(tags);
        return t.trimmed();
    }

    // a title part that is really a season / episode note ("Сезон: 2", "Серии: 1-10 из 10", "S01")
    bool isSeriesNote(const QString &part)
    {
        static const QRegularExpression note {u"^(сезон|серии|серия|season|episodes?|s\\d{1,2})\\b|:\\s*\\d"_s,
            QRegularExpression::CaseInsensitiveOption};
        return part.contains(note);
    }
}

FilmInfo FilmInfo::parse(const QString &name)
{
    FilmInfo film;
    const QString text = name.simplified();

    static const QRegularExpression qualityRe {u"\\b(2160p|4K|UHD|1080p|1080i|720p|576p|480p)\\b"_s, QRegularExpression::CaseInsensitiveOption};
    if (const QRegularExpressionMatch m = qualityRe.match(text); m.hasMatch())
    {
        const QString q = m.captured(1).toLower();
        film.quality = ((q == u"4k") || (q == u"uhd")) ? u"2160p"_s : (q == u"1080i") ? u"1080p"_s : q;
    }
    static const QRegularExpression seriesRe {u"(сезон|серии|season|\\bS\\d{1,2}(E\\d{1,3})?\\b|сериал)"_s, QRegularExpression::CaseInsensitiveOption};
    film.series = text.contains(seriesRe);

    // tracker style: "Title / Original (people) [year, …] …" — the titles end at the first bracket
    static const QRegularExpression trackerYear {u"[\\[\\(]\\s*((?:19|20)\\d\\d)\\b"_s};
    const qsizetype bracket = text.indexOf(QRegularExpression(u"\\s[\\(\\[]"_s));
    if (text.contains(u" / "_s) || ((bracket > 0) && text.contains(trackerYear)))
    {
        const QString head = (bracket > 0) ? text.left(bracket) : text;
        QStringList titles;
        for (const QString &part : head.split(u" / "_s))
        {
            const QString t = withoutTags(part.trimmed());
            if (!t.isEmpty() && !isSeriesNote(t))
                titles.append(t);
        }
        if (!titles.isEmpty())
        {
            film.title = titles.first();
            for (const QString &t : titles)
            {
                if (hasLatin(t))
                {
                    film.original = t;
                    break;
                }
            }
            if (const QRegularExpressionMatch m = trackerYear.match(text); m.hasMatch())
                film.year = m.captured(1).toInt();
        }
    }

    // scene style, or nothing found above
    if (film.title.isEmpty())
    {
        const QVariantMap parsed = MediaLibraryModel::parseName(text);
        film.title = parsed.value(u"title"_s).toString();
        film.year = parsed.value(u"year"_s).toInt();
        if (hasLatin(film.title))
            film.original = film.title;
        if (film.quality.isEmpty())
            film.quality = parsed.value(u"quality"_s).toString();
        film.series = film.series || parsed.contains(u"season"_s);
    }

    QString keyTitle = (film.original.isEmpty() ? film.title : film.original).toCaseFolded();
    static const QRegularExpression punctuation {u"[^\\w]+"_s, QRegularExpression::UseUnicodePropertiesOption};
    keyTitle.replace(punctuation, u" "_s);
    film.key = keyTitle.simplified() + u'|' + QString::number(film.year);
    return film;
}

QVariantMap FilmInfo::toMap() const
{
    return {{u"key"_s, key}, {u"title"_s, title}, {u"original"_s, original}, {u"year"_s, year},
        {u"quality"_s, quality}, {u"series"_s, series}};
}

Posters::Posters(QObject *parent)
    : QObject(parent)
{
}

int Posters::revision() const
{
    return m_revision;
}

QVariantMap Posters::film(const QString &name) const
{
    return FilmInfo::parse(name).toMap();
}

QString Posters::poster(const QString &key) const
{
    return m_posters.value(key);
}

QString Posters::pickPoster(const QByteArray &json, const int year, const bool series)
{
    const QJsonArray items = QJsonDocument::fromJson(json).object().value(u"d"_s).toArray();
    QString best;
    int bestScore = -1;
    for (const QJsonValue &value : items)
    {
        const QJsonObject item = value.toObject();
        const QString image = item.value(u"i"_s).toObject().value(u"imageUrl"_s).toString();
        const QString kind = item.value(u"qid"_s).toString();
        if (image.isEmpty() || !(kind.startsWith(u"movie") || kind.startsWith(u"tv") || (kind == u"video")))
            continue;

        int score = 1;
        const int y = item.value(u"y"_s).toInt();
        if ((year > 0) && (y > 0))
        {
            if (std::abs(y - year) > 1)
                continue;  // another film of the same name
            score += (y == year) ? 4 : 2;
        }
        if (series == kind.startsWith(u"tvSeries") || (series && kind.startsWith(u"tvMini")))
            score += 2;
        if (score > bestScore)
        {
            bestScore = score;
            best = image;
        }
    }
    // Amazon's image service resizes on the fly: 300 px wide is plenty for a card
    static const QRegularExpression sizePart {u"\\._V1_.*\\.(jpg|png)$"_s};
    if (best.contains(sizePart))
        best.replace(sizePart, u"._V1_SX300.\\1"_s);
    return best;
}

void Posters::request(const QString &key, const QString &title, const QString &original, const int year, const bool series)
{
    if (key.isEmpty() || m_asked.contains(key))
        return;
    const QString query = (original.isEmpty() ? title : original).simplified();
    if (query.size() < 2)
        return;
    m_asked.insert(key);
    m_queue.append({key, query, year, series});
    pump();
}

void Posters::pump()
{
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
        return;
    while ((m_running < PARALLEL) && !m_queue.isEmpty())
    {
        const Job job = m_queue.takeFirst();
        ++m_running;
        const QString url = u"https://v3.sg.media-imdb.com/suggestion/x/%1.json"_s
            .arg(QString::fromLatin1(QUrl::toPercentEncoding(job.query.toLower())));
        const Net::DownloadRequest request = Net::DownloadRequest(url).userAgent(USER_AGENT).limit(1024 * 1024);
        manager->download(request, true, this, [this, job](const Net::DownloadResult &result)
        {
            --m_running;
            if (result.status == Net::DownloadStatus::Success)
            {
                const QString url = pickPoster(result.data, job.year, job.series);
                if (!url.isEmpty())
                {
                    m_posters.insert(job.key, url);
                    ++m_revision;
                    emit revisionChanged();
                }
            }
            pump();
        });
    }
}
