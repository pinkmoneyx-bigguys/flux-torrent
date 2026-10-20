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

#include "appinfo.h"

#include <QClipboard>
#include <QDesktopServices>
#include <QGuiApplication>
#include <QUrl>

#include "base/global.h"
#include "base/path.h"
#include "base/profile.h"
#include "base/utils/misc.h"
#include "base/version.h"

#ifndef FLUX_VERSION
#define FLUX_VERSION "0.0.0"
#endif
#ifndef FLUX_GITHUB_REPO
#define FLUX_GITHUB_REPO ""
#endif
#ifndef FLUX_BUILD_COMMIT
#define FLUX_BUILD_COMMIT ""
#endif

AppInfo::AppInfo(QObject *parent)
    : QObject(parent)
{
}

QString AppInfo::name()
{
    return u"Flux"_s;
}

QString AppInfo::version()
{
    return QStringLiteral(FLUX_VERSION);
}

QString AppInfo::commit() const
{
    return QStringLiteral(FLUX_BUILD_COMMIT);
}

QString AppInfo::buildDate() const
{
    return QStringLiteral(__DATE__);
}

QString AppInfo::baseVersion() const
{
    return QStringLiteral(QBT_VERSION_2);
}

QString AppInfo::qtVersion() const
{
    return QString::fromLatin1(qVersion());
}

QString AppInfo::libtorrentVersion() const
{
    return Utils::Misc::libtorrentVersionString();
}

QString AppInfo::boostVersion() const
{
    return Utils::Misc::boostVersionString();
}

QString AppInfo::opensslVersion() const
{
    return Utils::Misc::opensslVersionString();
}

QString AppInfo::zlibVersion() const
{
    return Utils::Misc::zlibVersionString();
}

QString AppInfo::repository()
{
    return QStringLiteral(FLUX_GITHUB_REPO);
}

QString AppInfo::repositoryUrl() const
{
    return repository().isEmpty() ? QString() : u"https://github.com/"_s + repository();
}

QString AppInfo::releasesUrl() const
{
    return repository().isEmpty() ? QString() : repositoryUrl() + u"/releases"_s;
}

QString AppInfo::issuesUrl() const
{
    return repository().isEmpty() ? QString() : repositoryUrl() + u"/issues"_s;
}

QString AppInfo::profilePath() const
{
    const Profile *profile = Profile::instance();
    return profile ? profile->rootPath().toString() : QString();
}

void AppInfo::openUrl(const QString &url) const
{
    const QUrl target {url};
    if (target.isValid() && (target.scheme() == u"https"))
        QDesktopServices::openUrl(target);
}

void AppInfo::openProfileFolder() const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(profilePath()));
}

void AppInfo::copyDiagnostics() const
{
    const QString text = u"%1 %2%3\nqBittorrent %4 · Qt %5 · libtorrent %6 · Boost %7 · OpenSSL %8 · zlib %9"_s
        .arg(name(), version(), commit().isEmpty() ? QString() : u" (" + commit() + u')', baseVersion(), qtVersion()
            , libtorrentVersion(), boostVersion(), opensslVersion(), zlibVersion());
    if (QClipboard *clipboard = QGuiApplication::clipboard())
        clipboard->setText(text);
}
