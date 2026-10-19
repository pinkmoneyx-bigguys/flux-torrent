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

#include "profilemigrator.h"

#include <utility>

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QList>
#include <QtSystemDetection>

#ifdef Q_OS_WIN
#include <windows.h>
#include <tlhelp32.h>
#endif

#include "base/global.h"

namespace
{
    const QString STAGING_SUFFIX = u".fluxtmp"_s;
    const QString QBT_SETTINGS_FILE = u"qBittorrent.ini"_s;
    const QString FLUX_SETTINGS_FILE = u"Flux.ini"_s;
    const QString BACKUP_SUFFIX = u".bak"_s;

    struct CopyItem
    {
        QString from;
        QString to;
    };

    bool isNonEmptyDir(const QString &path)
    {
        return QFileInfo(path).isDir() && !QDir(path).isEmpty(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    }

    // Adds every file below `fromDir` (if it exists) to `items`, keeping the relative layout under `toDir`
    void addTree(QList<CopyItem> &items, const QString &fromDir, const QString &toDir)
    {
        if (!QFileInfo(fromDir).isDir())
            return;

        const QDir base {fromDir};
        QDirIterator it {fromDir, (QDir::Files | QDir::Hidden), QDirIterator::Subdirectories};
        while (it.hasNext())
        {
            const QString file = it.next();
            items.append({file, (toDir + u'/' + base.relativeFilePath(file))});
        }
    }

    void addFile(QList<CopyItem> &items, const QString &fromFile, const QString &toFile)
    {
        if (QFileInfo(fromFile).isFile())
            items.append({fromFile, toFile});
    }

    void removeStagingFiles(const QList<CopyItem> &items)
    {
        for (const CopyItem &item : items)
            QFile::remove(item.to + STAGING_SUFFIX);
    }

    QString &qbittorrentProcessName()
    {
        static QString name = u"qbittorrent.exe"_s;
        return name;
    }

    bool isFastresume(const QString &path)
    {
        return path.endsWith(u".fastresume"_s, Qt::CaseInsensitive);
    }
}

QString Flux::applicationName()
{
    return u"Flux"_s;
}

std::optional<Flux::QbtProfileLocation> Flux::findQbittorrentProfile(const Path &appData, const Path &localAppData)
{
    if (appData.isEmpty() || localAppData.isEmpty())
        return std::nullopt;

    const Path configDir = appData / Path(u"qBittorrent"_s);
    const Path dataDir = localAppData / Path(u"qBittorrent"_s);
    if (!QFileInfo(configDir.data() + u'/' + QBT_SETTINGS_FILE).isFile() || !QFileInfo(dataDir.data()).isDir())
        return std::nullopt;

    return QbtProfileLocation {configDir, dataDir};
}

std::optional<Flux::QbtProfileLocation> Flux::findQbittorrentProfile()
{
    return findQbittorrentProfile(Path(qEnvironmentVariable("APPDATA")), Path(qEnvironmentVariable("LOCALAPPDATA")));
}

int Flux::countTorrents(const QbtProfileLocation &profile)
{
    const QString backupDir = profile.dataDir.data() + u"/BT_backup"_s;
    if (!QFileInfo(backupDir).isDir())
        return 0;

    int count = 0;
    QDirIterator it {backupDir, {u"*.fastresume"_s}, QDir::Files, QDirIterator::Subdirectories};
    while (it.hasNext())
    {
        it.next();
        ++count;
    }
    return count;
}

bool Flux::isProcessRunning(const QString &exeName)
{
#ifdef Q_OS_WIN
    const HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
        return false;

    bool found = false;
    PROCESSENTRY32W entry {};
    entry.dwSize = sizeof(entry);
    for (BOOL more = ::Process32FirstW(snapshot, &entry); more; more = ::Process32NextW(snapshot, &entry))
    {
        if (QString::fromWCharArray(entry.szExeFile).compare(exeName, Qt::CaseInsensitive) == 0)
        {
            found = true;
            break;
        }
    }
    ::CloseHandle(snapshot);
    return found;
#else
    Q_UNUSED(exeName);
    return false;
#endif
}

bool Flux::isQbittorrentRunning()
{
    return isProcessRunning(qbittorrentProcessName());
}

void Flux::setQbittorrentProcessName(const QString &exeName)
{
    qbittorrentProcessName() = exeName;
}

Flux::MigrationResult Flux::migrateProfile(const QbtProfileLocation &from, const Path &toConfigDir,
                                           const Path &toDataDir, const bool overwrite)
{
    MigrationResult result;

    const QString fromConfig = from.configDir.data();
    const QString fromData = from.dataDir.data();
    const QString toConfig = toConfigDir.data();
    const QString toData = toDataDir.data();
    if (toConfig.isEmpty() || toData.isEmpty())
    {
        result.error = u"Invalid target directory"_s;
        return result;
    }

    const QString sourceSettings = fromConfig + u'/' + QBT_SETTINGS_FILE;
    if (!QFileInfo(sourceSettings).isFile())
    {
        result.error = u"qBittorrent settings not found: %1"_s.arg(QDir::toNativeSeparators(sourceSettings));
        return result;
    }

    // Plan: everything but Flux.ini, which is committed last
    QList<CopyItem> items;
    addFile(items, (fromConfig + u"/categories.json"_s), (toConfig + u"/categories.json"_s));
    addFile(items, (fromConfig + u"/watched_folders.json"_s), (toConfig + u"/watched_folders.json"_s));
    addTree(items, (fromConfig + u"/rss"_s), (toConfig + u"/rss"_s));
    addTree(items, (fromData + u"/BT_backup"_s), (toData + u"/BT_backup"_s));
    addTree(items, (fromData + u"/rss"_s), (toData + u"/rss"_s));
    const QString targetSettings = toConfig + u'/' + FLUX_SETTINGS_FILE;
    items.append({sourceSettings, targetSettings});

    // Refuse to mix with, or replace, data that Flux already has. Flux.ini is exempt: every start of Flux
    // creates it, and it is kept as a backup below.
    if (!overwrite)
    {
        const bool occupied = isNonEmptyDir(toData + u"/BT_backup"_s)
            || isNonEmptyDir(toData + u"/rss"_s)
            || isNonEmptyDir(toConfig + u"/rss"_s)
            || QFileInfo::exists(toConfig + u"/categories.json"_s)
            || QFileInfo::exists(toConfig + u"/watched_folders.json"_s);
        if (occupied)
        {
            result.error = u"target-not-empty"_s;
            return result;
        }
    }

    // A directory in place of a file cannot be replaced
    for (const CopyItem &item : asConst(items))
    {
        if (QFileInfo(item.to).isDir())
        {
            result.error = u"Cannot replace the directory with a file: %1"_s.arg(QDir::toNativeSeparators(item.to));
            return result;
        }
    }

    // Stage: copy every file to "<target>.fluxtmp". Nothing in the target is touched yet.
    for (qsizetype i = 0; i < items.size(); ++i)
    {
        const CopyItem &item = items.at(i);
        const QString staging = item.to + STAGING_SUFFIX;
        QString failure;
        if (!QDir().mkpath(QFileInfo(item.to).absolutePath()))
            failure = u"Cannot create the directory for %1"_s.arg(QDir::toNativeSeparators(item.to));
        else if (QFile::exists(staging) && !QFile::remove(staging))
            failure = u"Cannot remove the leftover file %1"_s.arg(QDir::toNativeSeparators(staging));
        else if (QFile file {item.from}; !file.copy(staging))
            failure = u"Cannot copy %1: %2"_s.arg(QDir::toNativeSeparators(item.from), file.errorString());

        if (!failure.isEmpty())
        {
            removeStagingFiles(items.first(i + 1));
            result.error = failure;
            return result;
        }
    }

    // Commit: move the staged files into place; the settings file is the last one
    int torrents = 0;
    for (qsizetype i = 0; i < items.size(); ++i)
    {
        const CopyItem &item = items.at(i);
        const bool isSettings = (i == items.size() - 1);
        QString failure;

        if (QFileInfo::exists(item.to))
        {
            if (isSettings)
            {
                const QString backup = item.to + BACKUP_SUFFIX;
                if (QFile::exists(backup) && !QFile::remove(backup))
                    failure = u"Cannot replace the backup %1"_s.arg(QDir::toNativeSeparators(backup));
                else if (!QFile::rename(item.to, backup))
                    failure = u"Cannot back up %1"_s.arg(QDir::toNativeSeparators(item.to));
            }
            else if (!QFile::remove(item.to))
            {
                failure = u"Cannot replace %1"_s.arg(QDir::toNativeSeparators(item.to));
            }
        }

        if (failure.isEmpty() && !QFile::rename((item.to + STAGING_SUFFIX), item.to))
            failure = u"Cannot move the copy into place: %1"_s.arg(QDir::toNativeSeparators(item.to));

        if (!failure.isEmpty())
        {
            removeStagingFiles(items.sliced(i));
            result.error = u"The transfer was interrupted after %1 file(s). %2"_s.arg(QString::number(i), failure);
            return result;
        }

        if (isFastresume(item.to) && item.to.contains(u"/BT_backup/"_s))
            ++torrents;
    }

    result.ok = true;
    result.torrentsCopied = torrents;
    return result;
}
