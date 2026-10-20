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

#include "updater.h"

#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QUrl>

#include "base/global.h"
#include "base/net/downloadmanager.h"
#include "base/settingsstorage.h"
#include "appinfo.h"

namespace
{
    const QString AUTO_CHECK_KEY = u"Flux/Updates/AutoCheck"_s;
    const QString LAST_CHECK_KEY = u"Flux/Updates/LastCheck"_s;
    const int DUE_AFTER_HOURS = 20;

    // without a profile (tests)
    bool g_autoCheck = true;

    // "v1.2.3-beta.2" → numbers {1, 2, 3} and the suffix "beta.2"
    void splitVersion(const QString &text, QList<int> &numbers, QString &suffix)
    {
        QString v = text.trimmed();
        if (v.startsWith(u'v', Qt::CaseInsensitive))
            v.remove(0, 1);
        const qsizetype dash = v.indexOf(QRegularExpression(u"[-+ ]"_s));
        suffix = (dash >= 0) ? v.mid(dash + 1) : QString();
        const QString core = (dash >= 0) ? v.left(dash) : v;
        for (const QString &part : core.split(u'.'))
            numbers.append(part.toInt());
        while ((numbers.size() > 1) && (numbers.last() == 0))
            numbers.removeLast();
    }
}

Updater::Updater(QObject *parent)
    : QObject(parent)
{
    if (const SettingsStorage *storage = SettingsStorage::instance())
        m_lastChecked = storage->loadValue<QDateTime>(LAST_CHECK_KEY);
}

int Updater::compareVersions(const QString &a, const QString &b)
{
    QList<int> na, nb;
    QString sa, sb;
    splitVersion(a, na, sa);
    splitVersion(b, nb, sb);
    for (qsizetype i = 0; i < std::max(na.size(), nb.size()); ++i)
    {
        const int x = na.value(i, 0);
        const int y = nb.value(i, 0);
        if (x != y)
            return (x < y) ? -1 : 1;
    }
    if (sa == sb)
        return 0;
    // a pre-release comes before its release
    if (sa.isEmpty())
        return 1;
    if (sb.isEmpty())
        return -1;
    return QString::compare(sa, sb, Qt::CaseInsensitive) < 0 ? -1 : 1;
}

QVariantMap Updater::parseRelease(const QByteArray &json)
{
    const QJsonObject release = QJsonDocument::fromJson(json).object();
    if (release.isEmpty() || !release.contains(u"tag_name"_s))
        return {};

    QVariantMap map {
        {u"version"_s, release.value(u"tag_name"_s).toString()},
        {u"name"_s, release.value(u"name"_s).toString()},
        {u"url"_s, release.value(u"html_url"_s).toString()},
        {u"notes"_s, release.value(u"body"_s).toString()},
        {u"draft"_s, release.value(u"draft"_s).toBool()},
        {u"prerelease"_s, release.value(u"prerelease"_s).toBool()}
    };

    // the file to offer: an installer, else an archive (Windows builds first)
    int bestRank = 0;
    for (const QJsonValue &value : release.value(u"assets"_s).toArray())
    {
        const QJsonObject asset = value.toObject();
        const QString name = asset.value(u"name"_s).toString();
        const QString lower = name.toLower();
        int rank = 0;
        if (lower.endsWith(u".exe") || lower.endsWith(u".msi"))
            rank = 4;
        else if (lower.endsWith(u".zip") || lower.endsWith(u".7z"))
            rank = 2;
        if ((rank > 0) && (lower.contains(u"win") || lower.contains(u"x64")))
            rank += 1;
        if (rank > bestRank)
        {
            bestRank = rank;
            map.insert(u"downloadUrl"_s, asset.value(u"browser_download_url"_s).toString());
            map.insert(u"downloadName"_s, name);
            map.insert(u"downloadSize"_s, asset.value(u"size"_s).toInteger());
        }
    }
    return map;
}

QString Updater::status() const { return m_status; }
QString Updater::error() const { return m_error; }
QString Updater::latestVersion() const { return m_release.value(u"version"_s).toString(); }
QString Updater::releaseName() const { return m_release.value(u"name"_s).toString(); }
QString Updater::releaseUrl() const { return m_release.value(u"url"_s).toString(); }
QString Updater::downloadUrl() const { return m_release.value(u"downloadUrl"_s).toString(); }
QString Updater::downloadName() const { return m_release.value(u"downloadName"_s).toString(); }
qint64 Updater::downloadSize() const { return m_release.value(u"downloadSize"_s).toLongLong(); }
QString Updater::notes() const { return m_release.value(u"notes"_s).toString(); }
QDateTime Updater::lastChecked() const { return m_lastChecked; }

bool Updater::autoCheck() const
{
    const SettingsStorage *storage = SettingsStorage::instance();
    return storage ? storage->loadValue<bool>(AUTO_CHECK_KEY, true) : g_autoCheck;
}

void Updater::setAutoCheck(const bool on)
{
    if (on == autoCheck())
        return;
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(AUTO_CHECK_KEY, on);
    else
        g_autoCheck = on;
    emit autoCheckChanged();
}

void Updater::finish(const QString &status, const QString &error)
{
    m_status = (m_quiet && (status == u"error")) ? u"idle"_s : status;
    m_error = error;
    m_lastChecked = QDateTime::currentDateTime();
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(LAST_CHECK_KEY, m_lastChecked);
    emit changed();
    if (status == u"available")
        emit updateAvailable(latestVersion());
}

void Updater::check(const bool quiet)
{
    if (m_status == u"checking")
        return;
    m_quiet = quiet;

    if (AppInfo::repository().isEmpty())
    {
        finish(u"error"_s, tr("This build does not say where its releases are published."));
        return;
    }
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
    {
        finish(u"error"_s, tr("The network is not ready."));
        return;
    }

    m_status = u"checking"_s;
    m_error.clear();
    emit changed();

    const QString url = u"https://api.github.com/repos/%1/releases/latest"_s.arg(AppInfo::repository());
    const Net::DownloadRequest request = Net::DownloadRequest(url)
        .userAgent(u"Flux/"_s + AppInfo::version()).limit(4 * 1024 * 1024);
    manager->download(request, true, this, [this](const Net::DownloadResult &result)
    {
        if (result.status != Net::DownloadStatus::Success)
        {
            // GitHub answers 404 while a repository has no published release
            const bool none = result.errorString.contains(u"404") || result.errorString.contains(u"Not Found", Qt::CaseInsensitive);
            if (none)
            {
                m_release.clear();
                finish(u"upToDate"_s);
                return;
            }
            finish(u"error"_s, tr("Could not reach GitHub: %1").arg(result.errorString));
            return;
        }
        const QVariantMap release = parseRelease(result.data);
        if (release.isEmpty())
        {
            finish(u"error"_s, tr("GitHub sent an answer Flux does not understand."));
            return;
        }
        m_release = release;
        const bool newer = !release.value(u"draft"_s).toBool() && !release.value(u"prerelease"_s).toBool()
            && (compareVersions(release.value(u"version"_s).toString(), AppInfo::version()) > 0);
        finish(newer ? u"available"_s : u"upToDate"_s);
    });
}

void Updater::checkIfDue()
{
    if (!autoCheck())
        return;
    if (m_lastChecked.isValid() && (m_lastChecked.secsTo(QDateTime::currentDateTime()) < DUE_AFTER_HOURS * 3600))
        return;
    check(true);
}

void Updater::openDownload() const
{
    const QString url = downloadUrl().isEmpty() ? releaseUrl() : downloadUrl();
    const QUrl target {url};
    if (target.isValid() && (target.scheme() == u"https"))
        QDesktopServices::openUrl(target);
}
