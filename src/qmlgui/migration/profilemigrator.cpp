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

#include <algorithm>
#include <utility>

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QList>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QStringList>
#include <QTemporaryDir>
#include <QtSystemDetection>

#ifdef Q_OS_WIN
#include <windows.h>
#include <tlhelp32.h>
#endif

#include "base/global.h"

namespace
{
    const QString STAGING_SUFFIX = u".fluxtmp"_s;
    const QString REPLACED_SUFFIX = u".fluxold"_s;
    const QString BACKUP_SUFFIX = u".bak"_s;
    const QString QBT_SETTINGS_FILE = u"qBittorrent.ini"_s;
    const QString FLUX_SETTINGS_FILE = u"Flux.ini"_s;
    const QString DATABASE_NAME = u"torrents.db"_s;
    // the database and its write-ahead log / shared-memory companions (journal_mode = WAL)
    const QStringList DATABASE_FILES = {DATABASE_NAME, (DATABASE_NAME + u"-wal"_s), (DATABASE_NAME + u"-shm"_s)};

    struct CopyItem
    {
        QString from;
        QString to;
        // An .ini that every Flux start may have created already: replaced after being kept as .bak, and
        // the paths into the qBittorrent profile in it are redirected to the Flux one
        bool isSettings = false;
    };

    Flux::RenameHook &renameHook()
    {
        static Flux::RenameHook hook;
        return hook;
    }

    bool renameStaged(const QString &from, const QString &to)
    {
        if (renameHook() && !renameHook()(from, to))
            return false;
        return QFile::rename(from, to);
    }

    // Whether there is a file below `path`, not counting the staging files of an interrupted attempt
    bool hasFiles(const QString &path)
    {
        if (!QFileInfo(path).isDir())
            return false;

        QDirIterator it {path, (QDir::Files | QDir::Hidden | QDir::System), QDirIterator::Subdirectories};
        while (it.hasNext())
        {
            if (!it.next().endsWith(STAGING_SUFFIX))
                return true;
        }
        return false;
    }

    void removeStagingFilesIn(const QString &path)
    {
        if (!QFileInfo(path).isDir())
            return;

        QDirIterator it {path, {QString(u'*' + STAGING_SUFFIX)}, (QDir::Files | QDir::Hidden), QDirIterator::Subdirectories};
        while (it.hasNext())
            QFile::remove(it.next());
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
            items.append({file, (toDir + u'/' + base.relativeFilePath(file)), false});
        }
    }

    void addFile(QList<CopyItem> &items, const QString &fromFile, const QString &toFile, const bool isSettings = false)
    {
        if (QFileInfo(fromFile).isFile())
            items.append({fromFile, toFile, isSettings});
    }

    void removeStagingFiles(const QList<CopyItem> &items)
    {
        for (const CopyItem &item : items)
            QFile::remove(item.to + STAGING_SUFFIX);
    }

    // `value` with the leading directory `fromDir` replaced by `toDir`, if it lies inside `fromDir`
    // (any case, any slash style). Null if it does not.
    QString redirected(const QString &value, const QString &fromDir, const QString &toDir)
    {
        QString normalized = value;
        normalized.replace(u'\\', u'/');
        QString from = fromDir;
        from.replace(u'\\', u'/');
        if (from.isEmpty() || !normalized.startsWith(from, Qt::CaseInsensitive))
            return {};
        // "<dir>-old" is another directory
        if ((normalized.size() > from.size()) && (normalized.at(from.size()) != u'/'))
            return {};
        return toDir + normalized.mid(from.size());
    }

    // The copy of qBittorrent's settings must not point Flux into the qBittorrent profile (the log
    // directory, for instance, which Flux would write to and rotate). Every string, or list of strings, that
    // lies inside one of the `directories` (from -> to) is moved to the Flux equivalent. A file where
    // nothing needs to change is left alone, byte for byte.
    bool rewriteProfilePaths(const QString &iniPath, const QList<std::pair<QString, QString>> &directories)
    {
        QSettings ini {iniPath, QSettings::IniFormat};
        bool changed = false;

        const auto redirect = [&directories](const QString &value) -> QString
        {
            for (const auto &[fromDir, toDir] : directories)
            {
                const QString result = redirected(value, fromDir, toDir);
                if (!result.isNull())
                    return result;
            }
            return {};
        };

        const QStringList keys = ini.allKeys();
        for (const QString &key : keys)
        {
            const QVariant value = ini.value(key);
            if (value.metaType().id() == QMetaType::QString)
            {
                const QString result = redirect(value.toString());
                if (!result.isNull())
                {
                    ini.setValue(key, result);
                    changed = true;
                }
            }
            else if (value.metaType().id() == QMetaType::QStringList)
            {
                QStringList list = value.toStringList();
                bool listChanged = false;
                for (QString &entry : list)
                {
                    const QString result = redirect(entry);
                    if (!result.isNull())
                    {
                        entry = result;
                        listChanged = true;
                    }
                }
                if (listChanged)
                {
                    ini.setValue(key, list);
                    changed = true;
                }
            }
        }

        if (!changed)
            return true;
        ini.sync();
        return ini.status() == QSettings::NoError;
    }

    // Number of rows of the `torrents` table (src/base/bittorrent/dbresumedatastorage.cpp), -1 if unreadable.
    // The database is read from a temporary copy: SQLite may rewrite the -shm file or the log of a database
    // that is opened, and the qBittorrent profile must stay exactly as it is.
    int countDatabaseTorrents(const QString &dbPath)
    {
        const QTemporaryDir tempDir;
        if (!tempDir.isValid())
            return -1;
        const QString copy = tempDir.filePath(DATABASE_NAME);
        if (!QFile::copy(dbPath, copy))
            return -1;
        if (QFileInfo::exists(dbPath + u"-wal"_s))
            QFile::copy((dbPath + u"-wal"_s), (copy + u"-wal"_s));

        static int counter = 0;
        const QString connection = u"flux-profile-migrator-%1"_s.arg(++counter);
        int count = -1;
        {
            auto db = QSqlDatabase::addDatabase(u"QSQLITE"_s, connection);
            db.setDatabaseName(copy);
            if (db.open())
            {
                QSqlQuery query {db};
                if (query.exec(u"SELECT COUNT(*) FROM `torrents`"_s) && query.next())
                    count = query.value(0).toInt();
            }
        }
        QSqlDatabase::removeDatabase(connection);
        return count;
    }

    // Whether qBittorrent keeps the resume data in torrents.db rather than BT_backup
    bool usesDatabase(const Flux::QbtProfileLocation &profile)
    {
        if (!QFileInfo(profile.dataDir.data() + u'/' + DATABASE_NAME).isFile())
            return false;

        // the qBittorrent profile has qBittorrent.ini, a migrated Flux one has Flux.ini
        QString iniPath = profile.configDir.data() + u'/' + QBT_SETTINGS_FILE;
        if (!QFileInfo::exists(iniPath))
            iniPath = profile.configDir.data() + u'/' + FLUX_SETTINGS_FILE;
        const QSettings ini {iniPath, QSettings::IniFormat};
        return ini.value(u"BitTorrent/Session/ResumeDataStorageType"_s).toString().compare(u"SQLite"_s, Qt::CaseInsensitive) == 0;
    }

    QString &qbittorrentProcessName()
    {
        static QString name = u"qbittorrent.exe"_s;
        return name;
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
    if (usesDatabase(profile))
        return countDatabaseTorrents(profile.dataDir.data() + u'/' + DATABASE_NAME);

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



void Flux::setRenameHook(RenameHook hook)
{
    renameHook() = std::move(hook);
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

    // Plan. The settings files come last: they are committed after everything they describe.
    QList<CopyItem> items;
    addFile(items, (fromConfig + u"/categories.json"_s), (toConfig + u"/categories.json"_s));
    addFile(items, (fromConfig + u"/watched_folders.json"_s), (toConfig + u"/watched_folders.json"_s));
    addTree(items, (fromConfig + u"/rss"_s), (toConfig + u"/rss"_s));
    addTree(items, (fromData + u"/BT_backup"_s), (toData + u"/BT_backup"_s));
    addTree(items, (fromData + u"/rss"_s), (toData + u"/rss"_s));
    // qBittorrent 5.x can keep the resume data in a SQLite database instead of BT_backup
    for (const QString &name : DATABASE_FILES)
        addFile(items, (fromData + u'/' + name), (toData + u'/' + name));
    // Flux reads the statistics and the RSS auto-download rules under the names qBittorrent gave them
    addFile(items, (fromConfig + u"/qBittorrent-data.ini"_s), (toConfig + u"/qBittorrent-data.ini"_s), true);
    addFile(items, (fromConfig + u"/qBittorrent-rss.ini"_s), (toConfig + u"/qBittorrent-rss.ini"_s), true);
    addFile(items, sourceSettings, (toConfig + u'/' + FLUX_SETTINGS_FILE), true);

    // A process killed in the middle of an earlier attempt leaves staging files behind: they are ours
    removeStagingFilesIn(toConfig);
    removeStagingFilesIn(toData);

    // Refuse to mix with, or replace, data that Flux already has. The settings files are exempt:
    // every start of Flux creates them, and they are kept as .bak below.
    if (!overwrite)
    {
        bool occupied = hasFiles(toData + u"/BT_backup"_s) || hasFiles(toData + u"/rss"_s) || hasFiles(toConfig + u"/rss"_s)
            || QFileInfo::exists(toConfig + u"/categories.json"_s)
            || QFileInfo::exists(toConfig + u"/watched_folders.json"_s);
        for (const QString &name : DATABASE_FILES)
            occupied = occupied || QFileInfo::exists(toData + u'/' + name);
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

    const int expectedTorrents = countTorrents(from);

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
        else if ((item.from == sourceSettings)
                 && !rewriteProfilePaths(staging, {{fromConfig, toConfig}, {fromData, toData}}))
            failure = u"Cannot update the paths in %1"_s.arg(QDir::toNativeSeparators(item.to));

        if (!failure.isEmpty())
        {
            removeStagingFiles(items.first(i + 1));
            result.error = failure;
            return result;
        }
    }

    // Commit: move the staged files into place. A replaced file is kept next to its new version
    // until everything is in place, so that any failure can put the target back as it was.
    struct Committed
    {
        QString path;
        QString replaced; // where the previous file waits, empty if there was none
    };
    QList<Committed> committed;
    QString failure;
    for (const CopyItem &item : asConst(items))
    {
        QString replaced;
        if (QFileInfo::exists(item.to))
        {
            replaced = item.to + (item.isSettings ? BACKUP_SUFFIX : REPLACED_SUFFIX);
            if (item.isSettings && QFile::exists(replaced))
                QFile::remove(replaced);
            if (!QFile::rename(item.to, replaced))
            {
                failure = u"Cannot set aside %1"_s.arg(QDir::toNativeSeparators(item.to));
                break;
            }
        }

        if (!renameStaged((item.to + STAGING_SUFFIX), item.to))
        {
            if (!replaced.isEmpty())
                QFile::rename(replaced, item.to);
            failure = u"Cannot move the copy into place: %1"_s.arg(QDir::toNativeSeparators(item.to));
            break;
        }
        committed.append({item.to, replaced});
    }

    if (!failure.isEmpty())
    {
        // Undo, newest first: remove what was placed, put back what was set aside
        for (auto it = committed.crbegin(); it != committed.crend(); ++it)
        {
            QFile::remove(it->path);
            if (!it->replaced.isEmpty())
                QFile::rename(it->replaced, it->path);
        }
        removeStagingFiles(items);
        result.error = u"The transfer was interrupted and has been undone. %1"_s.arg(failure);
        return result;
    }

    for (const Committed &entry : asConst(committed))
    {
        if (!entry.replaced.isEmpty() && entry.replaced.endsWith(REPLACED_SUFFIX))
            QFile::remove(entry.replaced);
    }

    result.ok = true;
    // Unknown (-1) if the database could not be read before the copy: ask the copy
    result.torrentsCopied = (expectedTorrents >= 0) ? expectedTorrents
                                                     : std::max(0, countTorrents({toConfigDir, toDataDir}));
    return result;
}
