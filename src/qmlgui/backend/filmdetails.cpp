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

#include "filmdetails.h"

#include <algorithm>
#include <chrono>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QList>
#include <QPair>
#include <QRegularExpression>
#include <QUrl>

#include "base/global.h"
#include "base/net/downloadmanager.h"
#include "languages.h"
#include "posters.h"

namespace
{
    const QString USER_AGENT = u"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Flux"_s;
    const std::chrono::milliseconds TIMEOUT {10000};

    bool hasCyrillic(const QString &text)
    {
        static const QRegularExpression cyrillic {u"[\\x{0400}-\\x{04FF}]"_s};
        return text.contains(cyrillic);
    }

    QString encoded(const QString &text)
    {
        return QString::fromLatin1(QUrl::toPercentEncoding(text));
    }

    // where to look, in order: {wiki, title}. The interface language's Wikipedia by the original title
    // first (its article often has that name), then the Russian one by the local title and the English
    // one by the original, Russian first for a Russian or Ukrainian interface.
    QList<QPair<QString, QString>> searchPlan(const QString &language, const QString &title, const QString &original)
    {
        const QString local = (hasCyrillic(title) && (title != original)) ? title : QString();
        QList<QPair<QString, QString>> plan;
        if ((language != u"en") && (language != u"ru") && !original.isEmpty())
            plan.append({language, original});
        const QPair<QString, QString> ru {u"ru"_s, local};
        const QPair<QString, QString> en {u"en"_s, original.isEmpty() ? title : original};
        if ((language == u"ru") || (language == u"uk"))
            plan << ru << en;
        else
            plan << en << ru;
        plan.removeIf([](const QPair<QString, QString> &step) { return step.second.size() < 2; });
        return plan;
    }

    QString extractUrl(const QString &wiki, const QString &article)
    {
        return u"https://%1.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&redirects=1"
            "&prop=extracts|pageimages|info|langlinks&exintro=1&explaintext=1&piprop=original&inprop=url&titles=%2"_s
            .arg(wiki, encoded(article));
    }
}

FilmDetails::FilmDetails(QObject *parent)
    : QObject(parent)
{
}

int FilmDetails::revision() const
{
    return m_revision;
}

QVariantMap FilmDetails::details(const QString &key) const
{
    return m_details.value(key);
}

void FilmDetails::request(const QString &key, const QString &title, const QString &original, const int year, const bool series)
{
    // the interface language's Wikipedia ("pt_BR" → pt); another language: the articles again
    QString language = Languages::effective().section(u'_', 0, 0).toLower();
    if (language.isEmpty())
        language = u"en"_s;
    if (language != m_language)
    {
        m_language = language;
        m_details.clear();
    }

    if (key.isEmpty() || m_details.contains(key))
        return;
    m_details.insert(key, {{u"state"_s, u"loading"_s}});
    ++m_revision;
    emit revisionChanged();

    Job job;
    job.key = key;
    job.title = title.simplified();
    job.original = original.simplified();
    job.year = year;
    job.series = series;
    search(job);
}

void FilmDetails::search(Job job)
{
    const QList<QPair<QString, QString>> plan = searchPlan(m_language, job.title, job.original);
    if (job.attempt >= plan.size())
    {
        finish(job, {});
        return;
    }
    const QString wiki = plan.at(job.attempt).first;
    const QString query = plan.at(job.attempt).second;
    const QString text = u"intitle:\"%1\" %2"_s.arg(query, (job.year > 0) ? QString::number(job.year) : QString()).trimmed();
    const QString url = u"https://%1.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&generator=search"
        "&gsrlimit=6&gsrsearch=%2&prop=description"_s.arg(wiki, encoded(text));
    fetch(url, [this, job, wiki, query](const bool ok, const QByteArray &data) mutable
    {
        const QString article = ok ? pickArticle(data, query, job.year, job.series) : QString();
        if (article.isEmpty())
        {
            ++job.attempt;
            search(job);
            return;
        }
        read(job, wiki, article, (wiki != m_language));
    });
}

void FilmDetails::read(const Job &job, const QString &wiki, const QString &article, const bool follow)
{
    QString url = extractUrl(wiki, article);
    if (follow)
        url += u"&lllang="_s + m_language;
    fetch(url, [this, job, wiki, follow](const bool ok, const QByteArray &data)
    {
        QVariantMap result = ok ? readArticle(data) : QVariantMap();
        if (result.value(u"text"_s).toString().isEmpty())
        {
            finish(job, {});
            return;
        }
        result.insert(u"lang"_s, wiki);
        const QString langlink = result.value(u"langlink"_s).toString();
        if (!follow || langlink.isEmpty())
        {
            finish(job, result);
            return;
        }
        // the same article in the interface language; this one if that one says nothing
        fetch(extractUrl(m_language, langlink), [this, job, result](const bool ok, const QByteArray &data)
        {
            QVariantMap translated = ok ? readArticle(data) : QVariantMap();
            if (translated.value(u"text"_s).toString().isEmpty())
            {
                finish(job, result);
                return;
            }
            translated.insert(u"lang"_s, m_language);
            if (translated.value(u"image"_s).toString().isEmpty())
            {
                translated.insert(u"image"_s, result.value(u"image"_s));
                translated.insert(u"portrait"_s, result.value(u"portrait"_s));
            }
            finish(job, translated);
        });
    });
}

void FilmDetails::finish(const Job &job, const QVariantMap &result)
{
    QVariantMap details = result;
    details.remove(u"langlink"_s);
    details.insert(u"state"_s, result.isEmpty() ? u"none"_s : u"ready"_s);
    if (!result.isEmpty())
        details.insert(u"text"_s, shorten(result.value(u"text"_s).toString()));
    m_details.insert(job.key, details);
    // a film without a poster gets the article's picture when it stands upright like one
    if (const QString image = details.value(u"image"_s).toString(); !image.isEmpty() && details.value(u"portrait"_s).toBool())
        Posters::instance()->offer(job.key, image);
    ++m_revision;
    emit revisionChanged();
}

void FilmDetails::fetch(const QString &url, const std::function<void (bool, const QByteArray &)> &done)
{
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
    {
        done(false, {});
        return;
    }
    const Net::DownloadRequest request = Net::DownloadRequest(url).userAgent(USER_AGENT).limit(2 * 1024 * 1024)
        .transferTimeout(TIMEOUT);
    manager->download(request, true, this, [done](const Net::DownloadResult &result)
    {
        done(result.status == Net::DownloadStatus::Success, result.data);
    });
}

QString FilmDetails::pickArticle(const QByteArray &json, const QString &title, const int year, const bool series)
{
    QList<QJsonObject> pages;
    for (const QJsonValue &value : QJsonDocument::fromJson(json).object().value(u"query"_s).toObject().value(u"pages"_s).toArray())
        pages.append(value.toObject());
    std::sort(pages.begin(), pages.end(), [](const QJsonObject &a, const QJsonObject &b)
    {
        return a.value(u"index"_s).toInt() < b.value(u"index"_s).toInt();
    });

    static const QRegularExpression note {u"\\s*\\([^)]*\\)\\s*$"_s};
    static const QRegularExpression screen {u"фильм|сериал|мульт|аниме|film|series|animated|anime|documentary|документальн|miniseries"
        "|película|serie|série|filme|téléfilm|fernseh|zeichentrick|serial|电影|电视剧|动画"_s, QRegularExpression::CaseInsensitiveOption};
    const QString wanted = FilmInfo::comparable(title);
    for (const QJsonObject &page : std::as_const(pages))
    {
        const QString pageTitle = page.value(u"title"_s).toString();
        const QString about = pageTitle + u' ' + page.value(u"description"_s).toString();
        QString bare = pageTitle;
        bare.remove(note);  // "Интерстеллар (фильм)"
        if (FilmInfo::comparable(bare) != wanted)
            continue;
        if (!about.contains(screen))
            continue;  // a book, a game or a song of that name
        if ((year > 0) && !series && pageTitle.contains(note))
        {
            // several films of that name: the one of this year
            const bool sameYear = about.contains(QString::number(year)) || about.contains(QString::number(year - 1))
                || about.contains(QString::number(year + 1));
            if (!sameYear)
                continue;
        }
        return pageTitle;
    }
    return {};
}

QVariantMap FilmDetails::readArticle(const QByteArray &json)
{
    const QJsonArray pages = QJsonDocument::fromJson(json).object().value(u"query"_s).toObject().value(u"pages"_s).toArray();
    if (pages.isEmpty())
        return {};
    const QJsonObject page = pages.first().toObject();
    if (page.contains(u"missing"_s))
        return {};
    const QJsonObject image = page.value(u"original"_s).toObject();
    const int width = image.value(u"width"_s).toInt();
    const int height = image.value(u"height"_s).toInt();
    QVariantMap article {
        {u"text"_s, page.value(u"extract"_s).toString().trimmed()},
        {u"url"_s, page.value(u"fullurl"_s).toString()},
        {u"image"_s, image.value(u"source"_s).toString()},
        {u"portrait"_s, (width > 0) && (height > width * 1.2)}
    };
    const QJsonArray langlinks = page.value(u"langlinks"_s).toArray();
    if (!langlinks.isEmpty())
        article.insert(u"langlink"_s, langlinks.first().toObject().value(u"title"_s).toString());
    return article;
}

QString FilmDetails::shorten(const QString &text, const int limit)
{
    // the opening paragraphs up to a sentence end, not much past the limit
    QString t = text;
    static const QRegularExpression blankLines {u"\\n{2,}"_s};
    t.replace(blankLines, u"\n"_s);
    if (t.size() <= limit)
        return t;
    static const QRegularExpression sentenceEnd {u"[.!?…](?=\\s|$)"_s};
    qsizetype cut = -1;
    for (auto it = sentenceEnd.globalMatch(t); it.hasNext();)
    {
        const QRegularExpressionMatch m = it.next();
        if ((m.capturedStart() + 1) > limit)
            break;
        cut = m.capturedStart() + 1;
    }
    if (cut < (limit / 2))
        return t.left(limit).trimmed() + u'…';
    return t.left(cut).trimmed();
}
