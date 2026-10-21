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

#include "jacredsearch.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QUrl>
#include <QUrlQuery>

#include "base/global.h"
#include "base/net/downloadmanager.h"

namespace
{
    // what JacRed calls its kinds of video, per search category
    QSet<QString> typesOf(const QString &category)
    {
        if (category == u"movies")
            return {u"movie"_s, u"multfilm"_s, u"documovie"_s};
        if (category == u"tv")
            return {u"serial"_s, u"multserial"_s, u"docuserial"_s, u"tvshow"_s};
        if (category == u"anime")
            return {u"anime"_s};
        return {};
    }

    // a browser-like agent: some mirrors turn away clients that do not send one
    const QString USER_AGENT = u"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Flux"_s;
}

JacRedSearch::JacRedSearch(QObject *parent)
    : QObject(parent)
{
}

bool JacRedSearch::covers(const QString &category)
{
    return category.isEmpty() || (category == u"all") || !typesOf(category).isEmpty();
}

QList<JacRedResult> JacRedSearch::parse(const QByteArray &json, const QString &category, const QString &baseUrl)
{
    const QSet<QString> wanted = typesOf(category);
    QList<JacRedResult> results;
    const QJsonArray items = QJsonDocument::fromJson(json).array();
    results.reserve(items.size());
    for (const QJsonValue &value : items)
    {
        const QJsonObject item = value.toObject();
        const QString magnet = item.value(u"magnet"_s).toString();
        const QString title = item.value(u"title"_s).toString();
        if (magnet.isEmpty() || title.isEmpty())
            continue;

        if (!wanted.isEmpty())
        {
            bool match = false;
            for (const QJsonValue &type : item.value(u"types"_s).toArray())
                match = match || wanted.contains(type.toString());
            if (!match)
                continue;
        }

        SearchResult r;
        r.fileName = title;
        r.fileUrl = magnet;
        r.fileSize = static_cast<qlonglong>(item.value(u"size"_s).toDouble(-1));
        r.nbSeeders = item.value(u"sid"_s).toInteger(-1);
        r.nbLeechers = item.value(u"pir"_s).toInteger(-1);
        r.engineName = item.value(u"tracker"_s).toString(u"jacred"_s);
        r.siteUrl = baseUrl;
        r.descrLink = item.value(u"url"_s).toString();
        r.pubDate = QDateTime::fromString(item.value(u"createTime"_s).toString(), Qt::ISODate);

        ReleaseMeta meta;
        meta.title = item.value(u"name"_s).toString().simplified();
        meta.original = item.value(u"originalname"_s).toString().simplified();
        meta.year = item.value(u"relased"_s).toInt();  // (sic)
        for (const QJsonValue &voice : item.value(u"voices"_s).toArray())
        {
            if (const QString v = voice.toString().simplified(); !v.isEmpty() && !meta.voices.contains(v, Qt::CaseInsensitive))
                meta.voices.append(v);
        }
        for (const QJsonValue &season : item.value(u"seasons"_s).toArray())
            meta.seasons.append(season.toInt());
        meta.video = item.value(u"videotype"_s).toString().toLower();
        results.append({r, meta});
    }
    return results;
}

void JacRedSearch::start(const QString &baseUrl, const QString &pattern, const QString &category)
{
    cancel();
    const int generation = ++m_generation;
    m_active = true;

    QString base = baseUrl.trimmed();
    if (base.isEmpty())
        base = DEFAULT_URL.toString();
    if (!base.contains(u"://"))
        base.prepend(u"https://"_s);
    while (base.endsWith(u'/'))
        base.chop(1);

    QUrl url {base + u"/api/v1.0/torrents"_s};
    QUrlQuery query;
    query.addQueryItem(u"search"_s, pattern);
    query.addQueryItem(u"apikey"_s, {});
    url.setQuery(query);

    auto *manager = Net::DownloadManager::instance();
    if (!manager)
    {
        m_active = false;
        emit finished(tr("The network is not ready."));
        return;
    }

    const Net::DownloadRequest request = Net::DownloadRequest(url.toString(QUrl::FullyEncoded))
        .userAgent(USER_AGENT).limit(32 * 1024 * 1024);
    manager->download(request, true, this, [this, generation, category, base](const Net::DownloadResult &result)
    {
        if (generation != m_generation)
            return;  // cancelled or replaced
        m_active = false;
        if (result.status != Net::DownloadStatus::Success)
        {
            emit finished(tr("JacRed did not answer: %1").arg(result.errorString));
            return;
        }
        const QList<JacRedResult> results = parse(result.data, category, base);
        if (!results.isEmpty())
            emit newResults(results);
        emit finished({});
    });
}

void JacRedSearch::cancel()
{
    ++m_generation;
    m_active = false;
}

bool JacRedSearch::isActive() const
{
    return m_active;
}
