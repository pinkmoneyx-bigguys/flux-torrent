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

#include <algorithm>
#include <chrono>

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QUrl>

#include "base/bittorrent/session.h"
#include "base/global.h"
#include "base/net/downloadmanager.h"
#include "base/path.h"
#include "base/profile.h"
#include "medialibrary.h"

namespace
{
    const int PER_SITE = 3;      // requests at a time to one site
    const int RETRIES = 2;       // a dropped request is tried again this many times
    const std::chrono::milliseconds TIMEOUT {8000};
    const int MISS_DAYS = 3;     // a film no source had is looked up again after this
    const int CACHE_VERSION = 1;
    const QString USER_AGENT = u"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Flux"_s;
    const QString SHIKIMORI = u"https://shikimori.io"_s;

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
    QString text = name.simplified();
    // tags before the titles: "[sub] Киберпанк: …", "[AniLibria.TV] …"
    static const QRegularExpression leadingTags {u"^(\\[[^\\]]{1,24}\\]\\s*)+"_s};
    text.remove(leadingTags);

    static const QRegularExpression qualityRe {u"\\b(2160p|4K|UHD|1080p|1080i|720p|576p|480p)\\b"_s, QRegularExpression::CaseInsensitiveOption};
    if (const QRegularExpressionMatch m = qualityRe.match(text); m.hasMatch())
    {
        const QString q = m.captured(1).toLower();
        film.quality = ((q == u"4k") || (q == u"uhd")) ? u"2160p"_s : (q == u"1080i") ? u"1080p"_s : q;
    }
    static const QRegularExpression seriesRe {u"(сезон|серии|season|\\bS\\d{1,2}(E\\d{1,3})?\\b|сериал)"_s, QRegularExpression::CaseInsensitiveOption};
    film.series = text.contains(seriesRe);

    // tracker style: "Title / Original (people) [year, …] …" — the titles end at the first bracket
    // (some trackers write "Original | Title [year, …]")
    static const QRegularExpression trackerYear {u"[\\[\\(]\\s*((?:19|20)\\d\\d)\\b"_s};
    static const QRegularExpression titleSeparator {u" [/|] "_s};
    const qsizetype bracket = text.indexOf(QRegularExpression(u"\\s[\\(\\[]"_s));
    const QString head = (bracket > 0) ? text.left(bracket) : text;
    if (text.contains(u" / "_s) || ((bracket > 0) && text.contains(trackerYear)))
    {
        QStringList titles;
        for (const QString &part : head.split(titleSeparator))
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

    film.key = keyOf(film.title, film.original, film.year);
    return film;
}

QString FilmInfo::keyOf(const QString &title, const QString &original, const int year)
{
    QString keyTitle = (original.isEmpty() ? title : original).toCaseFolded();
    static const QRegularExpression punctuation {u"[^\\w]+"_s, QRegularExpression::UseUnicodePropertiesOption};
    keyTitle.replace(punctuation, u" "_s);
    return keyTitle.simplified() + u'|' + QString::number(year);
}

QString FilmInfo::comparable(const QString &title)
{
    static const QRegularExpression punctuation {u"[^\\w]+"_s, QRegularExpression::UseUnicodePropertiesOption};
    QString t = title.toCaseFolded();
    t.replace(u'ё', u'е');
    t.replace(punctuation, u" "_s);
    return t.simplified();
}

QVariantMap FilmInfo::toMap() const
{
    return {{u"key"_s, key}, {u"title"_s, title}, {u"original"_s, original}, {u"year"_s, year},
        {u"quality"_s, quality}, {u"series"_s, series}};
}

Posters::Posters(const QString &cachePath, QObject *parent)
    : QObject(parent)
    , m_cachePath {cachePath}
{
    m_writeTimer.setSingleShot(true);
    m_writeTimer.setInterval(3000);
    connect(&m_writeTimer, &QTimer::timeout, this, &Posters::write);
    load();
    if (!m_cachePath.isEmpty())
    {
        m_imageDir = QFileInfo(m_cachePath).absolutePath() + u"/posters"_s;
        pruneImages();
    }
}

Posters::~Posters()
{
    if (m_writeTimer.isActive())
        write();
}

Posters *Posters::instance()
{
    // tests run without a session or profile: memory only
    static Posters *posters = new Posters(BitTorrent::Session::instance()
        ? (specialFolderLocation(SpecialFolder::Cache) / Path(u"posters.json"_s)).data()
        : QString(), QCoreApplication::instance());
    return posters;
}

Posters *Posters::create(QQmlEngine *, QJSEngine *)
{
    Posters *posters = instance();
    QJSEngine::setObjectOwnership(posters, QJSEngine::CppOwnership);
    return posters;
}

void Posters::setPoster(const QString &key, const QString &url)
{
    m_asked.insert(key);
    m_posters.insert(key, url);
    ++m_revision;
    emit revisionChanged();
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
    return m_posters.value(m_aliases.value(key, key));
}

QString Posters::image(const QString &key)
{
    const QString url = poster(key);
    if (url.isEmpty() || m_imageDir.isEmpty())
        return url;
    const QString file = fileOf(url);
    if (QFileInfo::exists(file))
        return QUrl::fromLocalFile(file).toString();
    if (!m_fetching.contains(url) && !m_failed.contains(url))
        fetchImage(url);
    return {};
}

QString Posters::fileOf(const QString &url) const
{
    const QByteArray hash = QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex();
    return m_imageDir + u'/' + QString::fromLatin1(hash) + u".img"_s;
}

void Posters::fetchImage(const QString &url, const int attempt)
{
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
        return;
    m_fetching.insert(url);
    const Net::DownloadRequest request = Net::DownloadRequest(url).userAgent(USER_AGENT).limit(8 * 1024 * 1024)
        .http2Allowed(false).transferTimeout(TIMEOUT);
    manager->download(request, true, this, [this, url, attempt](const Net::DownloadResult &result)
    {
        // a picture: JPEG, PNG, WebP or GIF, not an error page
        const QByteArray &data = result.data;
        const bool picture = data.startsWith("\xFF\xD8\xFF") || data.startsWith("\x89PNG") || data.startsWith("GIF8")
            || (data.startsWith("RIFF") && (data.mid(8, 4) == "WEBP"));
        if ((result.status != Net::DownloadStatus::Success) || !picture)
        {
            if (attempt < RETRIES)
            {
                QTimer::singleShot(std::chrono::milliseconds(1500 * (attempt + 1)), this, [this, url, attempt]
                {
                    fetchImage(url, attempt + 1);
                });
                return;
            }
            m_fetching.remove(url);
            m_failed.insert(url);
            return;
        }
        QDir().mkpath(m_imageDir);
        QSaveFile file {fileOf(url)};
        if (file.open(QIODevice::WriteOnly) && (file.write(data) == data.size()))
            file.commit();
        m_fetching.remove(url);
        ++m_revision;
        emit revisionChanged();
    });
}

void Posters::pruneImages()
{
    const int keep = 600;
    QDir dir {m_imageDir};
    const QFileInfoList files = dir.entryInfoList({u"*.img"_s}, QDir::Files, QDir::Time);  // newest first
    for (qsizetype i = keep; i < files.size(); ++i)
        QFile::remove(files.at(i).absoluteFilePath());
}

void Posters::alias(const QString &key, const QString &target)
{
    if ((key == target) || (m_aliases.value(key) == target))
        return;
    m_aliases.insert(key, target);
    if (m_posters.contains(target))
    {
        ++m_revision;
        emit revisionChanged();
    }
}

bool Posters::hasAlias(const QString &key) const
{
    return m_aliases.contains(key);
}

QString Posters::pickImdb(const QByteArray &json, const QString &title, const int year, const bool series)
{
    const QJsonArray items = QJsonDocument::fromJson(json).object().value(u"d"_s).toArray();
    const QString wanted = FilmInfo::comparable(title);
    QString best;
    int bestScore = -1;
    for (const QJsonValue &value : items)
    {
        const QJsonObject item = value.toObject();
        const QString image = item.value(u"i"_s).toObject().value(u"imageUrl"_s).toString();
        const QString kind = item.value(u"qid"_s).toString();
        if (image.isEmpty() || !(kind.startsWith(u"movie") || kind.startsWith(u"tv") || (kind == u"video")))
            continue;

        const int y = item.value(u"y"_s).toInt();
        if ((year > 0) && (y > 0) && (std::abs(y - year) > 1))
            continue;  // another film of the same name

        // the name should be this one; a suggestion that only looks alike (IMDb also finds by a Russian
        // title spelled in Latin) passes only when its year is exactly the one asked for
        const QString name = FilmInfo::comparable(item.value(u"l"_s).toString());
        int score = 1;
        if (!wanted.isEmpty() && (name == wanted))
            score += 6;
        else if ((year <= 0) || (y != year))
            continue;
        if ((year > 0) && (y > 0))
            score += (y == year) ? 4 : 1;
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

QString Posters::pickWikipedia(const QByteArray &json, const QString &title, const int year, const bool series)
{
    // in the order of the search
    QList<QJsonObject> pages;
    for (const QJsonValue &value : QJsonDocument::fromJson(json).object().value(u"query"_s).toObject().value(u"pages"_s).toArray())
        pages.append(value.toObject());
    std::sort(pages.begin(), pages.end(), [](const QJsonObject &a, const QJsonObject &b)
    {
        return a.value(u"index"_s).toInt() < b.value(u"index"_s).toInt();
    });

    static const QRegularExpression note {u"\\s*\\([^)]*\\)\\s*$"_s};
    static const QRegularExpression screen {u"фильм|сериал|мульт|аниме|film|series|animated|anime|documentary|документальн"_s,
        QRegularExpression::CaseInsensitiveOption};
    const QString wanted = FilmInfo::comparable(title);
    for (const QJsonObject &page : std::as_const(pages))
    {
        const QJsonObject thumb = page.value(u"thumbnail"_s).toObject();
        const QString image = thumb.value(u"source"_s).toString();
        // a poster stands upright; a still, a logo or a photo of the author mostly don't
        if (image.isEmpty() || (thumb.value(u"height"_s).toInt() < (thumb.value(u"width"_s).toInt() * 1.2)))
            continue;

        QString pageTitle = page.value(u"title"_s).toString();
        const QString about = pageTitle + u' ' + page.value(u"description"_s).toString();
        pageTitle.remove(note);  // "Интерстеллар (фильм)"
        if (FilmInfo::comparable(pageTitle) != wanted)
            continue;
        if (!about.contains(screen))
            continue;  // a book or a song of that name
        if (year > 0)
        {
            const bool sameYear = about.contains(QString::number(year)) || about.contains(QString::number(year - 1))
                || about.contains(QString::number(year + 1));
            // a series' page may only give the years it ran
            if (!sameYear && !series)
                continue;
        }
        return image;
    }
    return {};
}

QString Posters::pickShikimori(const QByteArray &json, const QString &title, const int year)
{
    const QJsonArray items = QJsonDocument::fromJson(json).array();
    const QString wanted = FilmInfo::comparable(title);
    for (const QJsonValue &value : items)
    {
        const QJsonObject item = value.toObject();
        if ((FilmInfo::comparable(item.value(u"name"_s).toString()) != wanted) && (FilmInfo::comparable(item.value(u"russian"_s).toString()) != wanted))
            continue;
        const int y = item.value(u"aired_on"_s).toString().left(4).toInt();
        if ((year > 0) && (y > 0) && (std::abs(y - year) > 1))
            continue;
        const QString image = item.value(u"image"_s).toObject().value(u"original"_s).toString();
        if (image.isEmpty() || image.contains(u"missing"))
            continue;
        return image.startsWith(u"http") ? image : (SHIKIMORI + image);
    }
    return {};
}

void Posters::request(const QString &key, const QString &title, const QString &original, const int year, const bool series)
{
    if (!key.isEmpty() && m_looking.contains(key))
    {
        // a card on screen asks: its film goes first in the queue it waits in
        for (QList<Job> &queue : m_queues)
        {
            const auto it = std::find_if(queue.begin(), queue.end(), [&key](const Job &job) { return job.key == key; });
            if (it != queue.end())
            {
                const Job job = *it;
                queue.erase(it);
                queue.prepend(job);
                break;
            }
        }
        return;
    }
    if (key.isEmpty() || m_asked.contains(key) || m_aliases.contains(key))
        return;
    m_asked.insert(key);
    if (m_posters.contains(key))
        return;  // found in an earlier session
    if (const QDateTime missed = m_missed.value(key); missed.isValid() && (missed.daysTo(QDateTime::currentDateTimeUtc()) < MISS_DAYS))
        return;  // none anywhere a little while ago

    Job job;
    job.key = key;
    job.title = title.simplified();
    job.original = original.simplified();
    job.year = year;
    job.series = series;
    job.source = -1;
    m_looking.insert(key);
    enqueueNext(job);
}

void Posters::retry(const QString &key, const QString &title, const QString &original, const int year, const bool series)
{
    const QString target = m_aliases.value(key, key);
    if (key.isEmpty() || m_posters.contains(target) || m_looking.contains(target))
        return;
    m_missed.remove(target);
    m_asked.remove(target);
    request(target, title, original, year, series);
}

void Posters::offer(const QString &key, const QString &url)
{
    const QString target = m_aliases.value(key, key);
    if (url.isEmpty() || m_posters.contains(target))
        return;
    found(target, url);
}

QString Posters::queryOf(const Job &job)
{
    // the local title, when it isn't the original one
    const QString local = (job.title != job.original) ? job.title : QString();
    switch (job.source)
    {
    case ImdbOriginal:
        return job.original;
    case ImdbLocal:
        // IMDb finds a film by its Russian title too, but loosely: only with a year to check against
        return (job.year > 0) ? local : QString();
    case WikipediaRu:
        return local;
    case WikipediaEn:
        return job.original;
    case Shikimori:
        return local.isEmpty() ? job.original : local;
    default:
        return {};
    }
}

QString Posters::urlOf(const Job &job)
{
    const QString query = queryOf(job);
    const auto encoded = [](const QString &text) { return QString::fromLatin1(QUrl::toPercentEncoding(text)); };
    switch (job.source)
    {
    case ImdbOriginal:
    case ImdbLocal:
        return u"https://v3.sg.media-imdb.com/suggestion/x/%1.json"_s.arg(encoded(query.toLower()));
    case WikipediaRu:
    case WikipediaEn:
        {
            const QString search = u"intitle:\"%1\" %2"_s.arg(query, (job.year > 0) ? QString::number(job.year) : QString()).trimmed();
            return u"https://%1.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search"
                "&gsrlimit=6&gsrsearch=%2&prop=pageimages|description&piprop=thumbnail&pithumbsize=300&pilicense=any"_s
                .arg((job.source == WikipediaRu) ? u"ru"_s : u"en"_s, encoded(search));
        }
    case Shikimori:
        return SHIKIMORI + u"/api/animes?limit=8&search=%1"_s.arg(encoded(query));
    default:
        return {};
    }
}

void Posters::enqueueNext(Job job)
{
    // the next source that can look this film up
    do
        ++job.source;
    while ((job.source < SourceCount) && (queryOf(job).size() < 2));

    if (job.source >= SourceCount)
    {
        m_looking.remove(job.key);
        // none had it: don't ask again for a few days (unless none answered at all: the network, then)
        if (!job.answered)
            return;
        m_missed.insert(job.key, QDateTime::currentDateTimeUtc());
        if (!m_writeTimer.isActive())
            m_writeTimer.start();
        return;
    }
    job.attempt = 0;
    m_queues[job.source].append(job);
    pump();
}

void Posters::pump()
{
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
        return;
    for (int source = 0; source < SourceCount; ++source)
    {
        while ((m_running[source] < PER_SITE) && !m_queues[source].isEmpty())
        {
            const Job job = m_queues[source].takeFirst();
            ++m_running[source];
            // HTTP/1.1 and a short wait: IMDb's servers leave HTTP/2 streams hanging when asked a lot at once
            const Net::DownloadRequest request = Net::DownloadRequest(urlOf(job)).userAgent(USER_AGENT).limit(1024 * 1024)
                .http2Allowed(false).transferTimeout(TIMEOUT);
            manager->download(request, true, this, [this, job](const Net::DownloadResult &result)
            {
                --m_running[job.source];
                finished(job, (result.status == Net::DownloadStatus::Success), result.data);
                pump();
            });
        }
    }
}

void Posters::finished(const Job &job, const bool ok, const QByteArray &data)
{
    if (!ok)
    {
        // sites drop a request now and then (IMDb closes HTTP/2 streams under load): try again a bit later
        if (job.attempt < RETRIES)
        {
            Job again = job;
            ++again.attempt;
            QTimer::singleShot(std::chrono::milliseconds(1200 * again.attempt), this, [this, again]
            {
                m_queues[again.source].append(again);
                pump();
            });
            return;
        }
        enqueueNext(job);
        return;
    }

    const QString query = queryOf(job);
    QString url;
    switch (job.source)
    {
    case ImdbOriginal:
    case ImdbLocal:
        url = pickImdb(data, (job.source == ImdbOriginal) ? query : QString(), job.year, job.series);
        break;
    case WikipediaRu:
    case WikipediaEn:
        url = pickWikipedia(data, query, job.year, job.series);
        break;
    case Shikimori:
        url = pickShikimori(data, query, job.year);
        break;
    default:
        break;
    }
    if (url.isEmpty())
    {
        Job next = job;
        next.answered = true;
        enqueueNext(next);
    }
    else
    {
        m_looking.remove(job.key);
        found(job.key, url);
    }
}

void Posters::found(const QString &key, const QString &url)
{
    m_posters.insert(key, url);
    m_missed.remove(key);
    ++m_revision;
    emit revisionChanged();
    if (!m_writeTimer.isActive())
        m_writeTimer.start();
}

void Posters::load()
{
    if (m_cachePath.isEmpty())
        return;
    QFile file {m_cachePath};
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    if (root.value(u"version"_s).toInt() != CACHE_VERSION)
        return;  // made by an older lookup: ask again

    const QJsonObject found = root.value(u"found"_s).toObject();
    for (auto it = found.begin(); it != found.end(); ++it)
        m_posters.insert(it.key(), it.value().toString());
    const QJsonObject missed = root.value(u"missed"_s).toObject();
    const QDateTime now = QDateTime::currentDateTimeUtc();
    for (auto it = missed.begin(); it != missed.end(); ++it)
    {
        const QDateTime when = QDateTime::fromString(it.value().toString(), Qt::ISODate);
        if (when.isValid() && (when.daysTo(now) < MISS_DAYS))
            m_missed.insert(it.key(), when);
    }
}

void Posters::write()
{
    if (m_cachePath.isEmpty())
        return;

    QJsonObject found;
    for (auto it = m_posters.cbegin(); it != m_posters.cend(); ++it)
        found.insert(it.key(), it.value());
    QJsonObject missed;
    for (auto it = m_missed.cbegin(); it != m_missed.cend(); ++it)
        missed.insert(it.key(), it.value().toString(Qt::ISODate));
    const QJsonObject root {{u"version"_s, CACHE_VERSION}, {u"found"_s, found}, {u"missed"_s, missed}};

    QDir().mkpath(QFileInfo(m_cachePath).absolutePath());
    QSaveFile file {m_cachePath};
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
    file.commit();
}
