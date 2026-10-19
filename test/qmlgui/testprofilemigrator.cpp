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

#include <QCoreApplication>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QObject>
#include <QScopeGuard>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QUuid>

#include "base/global.h"
#include "base/path.h"
#include "base/profile.h"
#include "qmlgui/migration/profilemigrator.h"

namespace
{
    void writeFile(const QString &path, const QByteArray &content)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file {path};
        if (!file.open(QIODevice::WriteOnly))
            qFatal("Cannot write %s", qUtf8Printable(path));
        file.write(content);
    }

    // Relative paths of all files below `root`, sorted
    QStringList listFiles(const QString &root)
    {
        QStringList files;
        QDirIterator it {root, QDir::Files | QDir::Hidden, QDirIterator::Subdirectories};
        const QDir base {root};
        while (it.hasNext())
            files.append(base.relativeFilePath(it.next()));
        files.sort();
        return files;
    }

    QByteArray readFile(const QString &path)
    {
        QFile file {path};
        return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
    }

    // A fake qBittorrent profile: <root>/appdata/qBittorrent and <root>/local/qBittorrent
    struct FakeQbt
    {
        QString appData;
        QString localAppData;
        QString configDir() const { return appData + u"/qBittorrent"_s; }
        QString dataDir() const { return localAppData + u"/qBittorrent"_s; }
    };

    FakeQbt makeFakeQbt(const QString &root, const bool withRss = true)
    {
        const FakeQbt qbt {(root + u"/appdata"_s), (root + u"/local"_s)};
        writeFile(qbt.configDir() + u"/qBittorrent.ini"_s, "[BitTorrent]\r\nSession\\Port=6881\r\n");
        writeFile(qbt.configDir() + u"/categories.json"_s, R"({"movies":{"save_path":"D:/m"}})");
        writeFile(qbt.dataDir() + u"/BT_backup/a.fastresume"_s, "fr-a");
        writeFile(qbt.dataDir() + u"/BT_backup/a.torrent"_s, "t-a");
        writeFile(qbt.dataDir() + u"/BT_backup/b.fastresume"_s, "fr-b");
        writeFile(qbt.dataDir() + u"/BT_backup/b.torrent"_s, "t-b");
        if (withRss)
            writeFile(qbt.dataDir() + u"/rss/feeds.json"_s, "{}");
        return qbt;
    }

    // A resume-data database with the schema of src/base/bittorrent/dbresumedatastorage.cpp (version 6)
    void writeResumeDb(const QString &path, const int torrents)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        const QString connection = u"testprofilemigrator-db"_s;
        {
            auto db = QSqlDatabase::addDatabase(u"QSQLITE"_s, connection);
            db.setDatabaseName(path);
            if (!db.open())
                qFatal("Cannot create %s", qUtf8Printable(path));
            QSqlQuery query {db};
            const QStringList statements = {
                u"CREATE TABLE `meta` (`id` INTEGER PRIMARY KEY, `name` TEXT NOT NULL UNIQUE, `value` BLOB)"_s,
                u"INSERT INTO `meta` (`name`, `value`) VALUES ('version', 6)"_s,
                (u"CREATE TABLE `torrents` (`id` INTEGER PRIMARY KEY, `torrent_id` BLOB NOT NULL UNIQUE,"
                 u" `queue_position` INTEGER NOT NULL DEFAULT -1, `name` TEXT, `category` TEXT, `tags` TEXT,"
                 u" `comment` TEXT, `target_save_path` TEXT, `download_path` TEXT, `content_layout` TEXT NOT NULL,"
                 u" `ratio_limit` INTEGER NOT NULL, `seeding_time_limit` INTEGER NOT NULL,"
                 u" `inactive_seeding_time_limit` INTEGER NOT NULL, `share_limit_action` TEXT NOT NULL DEFAULT 'Default',"
                 u" `has_outer_pieces_priority` INTEGER NOT NULL, `has_seed_status` INTEGER NOT NULL,"
                 u" `operating_mode` TEXT NOT NULL, `stopped` INTEGER NOT NULL,"
                 u" `stop_condition` TEXT NOT NULL DEFAULT 'None', `ssl_certificate` TEXT, `ssl_private_key` TEXT,"
                 u" `ssl_dh_params` TEXT, `libtorrent_resume_data` BLOB NOT NULL, `metadata` BLOB)"_s)
            };
            for (const QString &statement : statements)
            {
                if (!query.exec(statement))
                    qFatal("%s", qUtf8Printable(query.lastError().text()));
            }
            for (int i = 0; i < torrents; ++i)
            {
                query.prepare(u"INSERT INTO `torrents` (`torrent_id`, `queue_position`, `name`, `content_layout`,"
                              u" `ratio_limit`, `seeding_time_limit`, `inactive_seeding_time_limit`,"
                              u" `has_outer_pieces_priority`, `has_seed_status`, `operating_mode`, `stopped`,"
                              u" `libtorrent_resume_data`) VALUES (?, ?, ?, 'Original', -2, -2, -2, 0, 0, 'AutoManaged', 0, ?)"_s);
                query.addBindValue(QByteArray::number(i + 1000));
                query.addBindValue(i);
                query.addBindValue(u"torrent %1"_s.arg(i));
                query.addBindValue(QByteArray("resume"));
                if (!query.exec())
                    qFatal("%s", qUtf8Printable(query.lastError().text()));
            }
        }
        QSqlDatabase::removeDatabase(connection);
    }

    // The qBittorrent 5.x profile that keeps its resume data in torrents.db instead of BT_backup
    FakeQbt makeSqliteQbt(const QString &root, const int torrents)
    {
        const FakeQbt qbt {(root + u"/appdata"_s), (root + u"/local"_s)};
        writeFile(qbt.configDir() + u"/qBittorrent.ini"_s,
                  "[BitTorrent]\r\nSession\\ResumeDataStorageType=SQLite\r\n");
        writeResumeDb(qbt.dataDir() + u"/torrents.db"_s, torrents);
        return qbt;
    }

    Flux::QbtProfileLocation locationOf(const FakeQbt &qbt)
    {
        return {Path(qbt.configDir()), Path(qbt.dataDir())};
    }
}

class TestProfileMigrator final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestProfileMigrator)

public:
    TestProfileMigrator() = default;

private slots:
    void findsProfile() const
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const FakeQbt qbt = makeFakeQbt(dir.path());

        const auto found = Flux::findQbittorrentProfile(Path(qbt.appData), Path(qbt.localAppData));
        QVERIFY(found.has_value());
        QCOMPARE(found->configDir, Path(qbt.configDir()));
        QCOMPARE(found->dataDir, Path(qbt.dataDir()));
    }

    void noProfile() const
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        QVERIFY(!Flux::findQbittorrentProfile(Path(dir.path() + u"/a"_s), Path(dir.path() + u"/l"_s)).has_value());

        // the config dir alone, without qBittorrent.ini, is not a profile either
        QVERIFY(QDir().mkpath(dir.path() + u"/a/qBittorrent"_s));
        QVERIFY(QDir().mkpath(dir.path() + u"/l/qBittorrent"_s));
        QVERIFY(!Flux::findQbittorrentProfile(Path(dir.path() + u"/a"_s), Path(dir.path() + u"/l"_s)).has_value());
    }

    void countsTorrents() const
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const FakeQbt qbt = makeFakeQbt(dir.path());
        QCOMPARE(Flux::countTorrents(locationOf(qbt)), 2);

        QTemporaryDir empty;
        QCOMPARE(Flux::countTorrents({Path(empty.path()), Path(empty.path())}), 0);
    }

    void copiesEverything() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;

        const Flux::MigrationResult result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 2);
        QVERIFY(QFileInfo::exists(toConfig + u"/Flux.ini"_s));
        QCOMPARE(readFile(toConfig + u"/Flux.ini"_s), readFile(qbt.configDir() + u"/qBittorrent.ini"_s));
        QVERIFY(!readFile(toConfig + u"/Flux.ini"_s).isEmpty());
        QVERIFY(!QFileInfo::exists(toConfig + u"/qBittorrent.ini"_s));
        QCOMPARE(readFile(toConfig + u"/categories.json"_s), readFile(qbt.configDir() + u"/categories.json"_s));
        QCOMPARE(readFile(toData + u"/rss/feeds.json"_s), QByteArray("{}"));
        QCOMPARE(readFile(toData + u"/BT_backup/a.fastresume"_s), QByteArray("fr-a"));
        QCOMPARE(readFile(toData + u"/BT_backup/b.torrent"_s), QByteArray("t-b"));

        // the source profile is left as it was
        QVERIFY(QFileInfo::exists(qbt.configDir() + u"/qBittorrent.ini"_s));
        QCOMPARE(Flux::countTorrents(locationOf(qbt)), 2);

        // no staging files are left behind
        QVERIFY(QDir(toData + u"/BT_backup"_s).entryList({u"*.fluxtmp"_s}, QDir::Files).isEmpty());
        QCOMPARE(QDir(toData + u"/BT_backup"_s).entryList(QDir::Files).size(), 4);
    }

    void copiesNestedRssAndWatchedFolders() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        writeFile(qbt.configDir() + u"/watched_folders.json"_s, "{}");
        writeFile(qbt.configDir() + u"/rss/rules/r.json"_s, "[]");
        writeFile(qbt.dataDir() + u"/rss/articles/x/y.json"_s, "[1]");

        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(readFile(toConfig + u"/watched_folders.json"_s), QByteArray("{}"));
        QCOMPARE(readFile(toConfig + u"/rss/rules/r.json"_s), QByteArray("[]"));
        QCOMPARE(readFile(toData + u"/rss/articles/x/y.json"_s), QByteArray("[1]"));
    }

    void missingRssIsFine() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path(), false);

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(dst.path() + u"/config"_s),
                                                 Path(dst.path() + u"/data"_s), false);
        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 2);
        QVERIFY(!QFileInfo::exists(dst.path() + u"/data/rss"_s));
    }

    void refusesNonEmptyTarget() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        writeFile(toData + u"/BT_backup/mine.fastresume"_s, "mine");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY(!result.ok);
        QCOMPARE(result.error, u"target-not-empty"_s);
        QCOMPARE(result.torrentsCopied, 0);
        QCOMPARE(readFile(toData + u"/BT_backup/mine.fastresume"_s), QByteArray("mine"));
        // nothing was copied next to it
        QCOMPARE(QDir(toData + u"/BT_backup"_s).entryList(QDir::Files).size(), 1);
        QVERIFY(!QFileInfo::exists(toConfig + u"/Flux.ini"_s));
    }

    void refusesExistingCategories() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        writeFile(toConfig + u"/categories.json"_s, "mine");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(dst.path() + u"/data"_s), false);
        QVERIFY(!result.ok);
        QCOMPARE(result.error, u"target-not-empty"_s);
        QCOMPARE(readFile(toConfig + u"/categories.json"_s), QByteArray("mine"));
    }

    void overwriteAllowed() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        writeFile(toData + u"/BT_backup/a.fastresume"_s, "old");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), true);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 2);
        QCOMPARE(readFile(toData + u"/BT_backup/a.fastresume"_s), QByteArray("fr-a"));
    }

    void existingFluxIniIsNotAConflictButIsBackedUp() const
    {
        // A fresh Flux run writes its default Flux.ini before the first-run dialog is answered
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        writeFile(toConfig + u"/Flux.ini"_s, "[Flux]\r\ndefaults=1\r\n");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(dst.path() + u"/data"_s), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(readFile(toConfig + u"/Flux.ini"_s), readFile(qbt.configDir() + u"/qBittorrent.ini"_s));
        QCOMPARE(readFile(toConfig + u"/Flux.ini.bak"_s), QByteArray("[Flux]\r\ndefaults=1\r\n"));
    }

    void failureLeavesTargetUntouched() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        // a directory sits where the copy of a source file must go, so that file cannot be written
        QVERIFY(QDir().mkpath(toData + u"/BT_backup/b.torrent/inner"_s));

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), true);

        QVERIFY(!result.ok);
        QVERIFY(!result.error.isEmpty());
        QVERIFY(result.error != u"target-not-empty"_s);
        QCOMPARE(result.torrentsCopied, 0);
        // none of the other files got through, and no staging files remain
        QVERIFY(!QFileInfo::exists(toData + u"/BT_backup/a.fastresume"_s));
        QVERIFY(!QFileInfo::exists(toConfig + u"/Flux.ini"_s));
        QVERIFY(QFileInfo(toData + u"/BT_backup/b.torrent"_s).isDir());
        QVERIFY(QDir(toData + u"/BT_backup"_s).entryList({u"*.fluxtmp"_s}, QDir::Files).isEmpty());
    }

    void countsSqliteTorrents() const
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const FakeQbt qbt = makeSqliteQbt(dir.path(), 3);
        QCOMPARE(Flux::countTorrents(locationOf(qbt)), 3);
    }

    void unreadableDatabaseCountsAsUnknown() const
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const FakeQbt qbt = makeSqliteQbt(dir.path(), 1);
        writeFile(qbt.dataDir() + u"/torrents.db"_s, "this is not a database");
        QCOMPARE(Flux::countTorrents(locationOf(qbt)), -1);
    }

    void migratesSqliteProfile() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeSqliteQbt(src.path(), 3);
        const QString toData = dst.path() + u"/data"_s;

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(dst.path() + u"/config"_s), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 3);
        QCOMPARE(readFile(toData + u"/torrents.db"_s), readFile(qbt.dataDir() + u"/torrents.db"_s));
        QCOMPARE(Flux::countTorrents({Path(dst.path() + u"/config"_s), Path(toData)}), 3);
    }

    void copiesDatabaseJournalFiles() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeSqliteQbt(src.path(), 1);
        writeFile(qbt.dataDir() + u"/torrents.db-wal"_s, "wal-bytes");
        writeFile(qbt.dataDir() + u"/torrents.db-shm"_s, "shm-bytes");
        const QString toData = dst.path() + u"/data"_s;

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(dst.path() + u"/config"_s), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(readFile(toData + u"/torrents.db-wal"_s), QByteArray("wal-bytes"));
        QCOMPARE(readFile(toData + u"/torrents.db-shm"_s), QByteArray("shm-bytes"));
    }

    void refusesExistingTargetDatabase() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeSqliteQbt(src.path(), 3);
        const QString toData = dst.path() + u"/data"_s;
        writeFile(toData + u"/torrents.db"_s, "mine");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(dst.path() + u"/config"_s), Path(toData), false);

        QVERIFY(!result.ok);
        QCOMPARE(result.error, u"target-not-empty"_s);
        QCOMPARE(readFile(toData + u"/torrents.db"_s), QByteArray("mine"));
        QVERIFY(!QFileInfo::exists(dst.path() + u"/config/Flux.ini"_s));
    }

    void copiesStatisticsAndRssSettings() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        writeFile(qbt.configDir() + u"/qBittorrent-data.ini"_s, "[Stats]\r\nAllStats=@Variant(stats)\r\n");
        writeFile(qbt.configDir() + u"/qBittorrent-rss.ini"_s, "[AutoDownloader]\r\nRules=@Variant(rules)\r\n");
        const QString toConfig = dst.path() + u"/config"_s;
        // Flux reads these under the qBittorrent names; an earlier Flux run may have created them
        writeFile(toConfig + u"/qBittorrent-data.ini"_s, "[Stats]\r\nold=1\r\n");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(dst.path() + u"/data"_s), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(readFile(toConfig + u"/qBittorrent-data.ini"_s), readFile(qbt.configDir() + u"/qBittorrent-data.ini"_s));
        QCOMPARE(readFile(toConfig + u"/qBittorrent-rss.ini"_s), readFile(qbt.configDir() + u"/qBittorrent-rss.ini"_s));
        QCOMPARE(readFile(toConfig + u"/qBittorrent-data.ini.bak"_s), QByteArray("[Stats]\r\nold=1\r\n"));
    }

    void pathsIntoTheQbittorrentProfileAreRewritten() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        {
            QSettings ini {qbt.configDir() + u"/qBittorrent.ini"_s, QSettings::IniFormat};
            ini.setValue(u"Application/FileLogger/Path"_s, QString(qbt.dataDir() + u"/logs"_s));
            // another spelling of the same place: upper case, backslashes
            ini.setValue(u"Some/Dir"_s, QString(QDir::toNativeSeparators(qbt.configDir()).toUpper() + u"\\sub"_s));
            ini.setValue(u"Some/List"_s, QStringList {(qbt.dataDir() + u"/a"_s), u"D:/keep"_s});
            ini.setValue(u"Downloads/SavePath"_s, u"D:/Downloads"_s);
            // looks like the profile directory, but is a different one
            ini.setValue(u"Some/Sibling"_s, QString(qbt.dataDir() + u"-old/logs"_s));
            ini.setValue(u"Some/Number"_s, 42);
        }
        const QByteArray original = readFile(qbt.configDir() + u"/qBittorrent.ini"_s);

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QSettings ini {toConfig + u"/Flux.ini"_s, QSettings::IniFormat};
        QCOMPARE(ini.value(u"Application/FileLogger/Path"_s).toString(), toData + u"/logs"_s);
        QCOMPARE(QDir::fromNativeSeparators(ini.value(u"Some/Dir"_s).toString()).toLower(), (toConfig + u"/sub"_s).toLower());
        QCOMPARE(ini.value(u"Some/List"_s).toStringList(), QStringList({(toData + u"/a"_s), u"D:/keep"_s}));
        QCOMPARE(ini.value(u"Downloads/SavePath"_s).toString(), u"D:/Downloads"_s);
        QCOMPARE(ini.value(u"Some/Sibling"_s).toString(), qbt.dataDir() + u"-old/logs"_s);
        QCOMPARE(ini.value(u"Some/Number"_s).toInt(), 42);
        // the source profile keeps pointing at itself
        QCOMPARE(readFile(qbt.configDir() + u"/qBittorrent.ini"_s), original);
    }

    void commitFailureRollsBack() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        // the second BT_backup file cannot be moved into place
        Flux::setRenameHook([](const QString &, const QString &to) { return !to.endsWith(u"/b.fastresume"_s); });
        const auto resetHook = qScopeGuard([] { Flux::setRenameHook({}); });

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY(!result.ok);
        QVERIFY(result.error != u"target-not-empty"_s);
        QVERIFY2(result.error.contains(u"b.fastresume"_s), qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 0);
        // not a single migrated file is left: the next attempt starts from scratch
        QVERIFY(listFiles(toData).isEmpty());
        QVERIFY(listFiles(toConfig).isEmpty());

        // and the retry works
        Flux::setRenameHook({});
        const auto retry = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);
        QVERIFY2(retry.ok, qUtf8Printable(retry.error));
        QCOMPARE(retry.torrentsCopied, 2);
    }

    void commitFailureRestoresReplacedFiles() const
    {
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        writeFile(toData + u"/BT_backup/a.fastresume"_s, "old");
        writeFile(toConfig + u"/Flux.ini"_s, "[Flux]\r\nmine=1\r\n");
        const QStringList before = listFiles(dst.path());
        Flux::setRenameHook([](const QString &, const QString &to) { return !to.endsWith(u"/Flux.ini"_s); });
        const auto resetHook = qScopeGuard([] { Flux::setRenameHook({}); });

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), true);

        QVERIFY(!result.ok);
        QCOMPARE(listFiles(dst.path()), before);
        QCOMPARE(readFile(toData + u"/BT_backup/a.fastresume"_s), QByteArray("old"));
        QCOMPARE(readFile(toConfig + u"/Flux.ini"_s), QByteArray("[Flux]\r\nmine=1\r\n"));
    }

    void staleStagingFilesDoNotBlockTheMigration() const
    {
        // A process killed while copying leaves *.fluxtmp files behind
        QTemporaryDir src;
        QTemporaryDir dst;
        QVERIFY(src.isValid() && dst.isValid());
        const FakeQbt qbt = makeFakeQbt(src.path());
        const QString toConfig = dst.path() + u"/config"_s;
        const QString toData = dst.path() + u"/data"_s;
        writeFile(toData + u"/BT_backup/a.fastresume.fluxtmp"_s, "half");
        writeFile(toData + u"/BT_backup/old-name.torrent.fluxtmp"_s, "half");
        writeFile(toConfig + u"/categories.json.fluxtmp"_s, "half");

        const auto result = Flux::migrateProfile(locationOf(qbt), Path(toConfig), Path(toData), false);

        QVERIFY2(result.ok, qUtf8Printable(result.error));
        QCOMPARE(result.torrentsCopied, 2);
        QCOMPARE(readFile(toData + u"/BT_backup/a.fastresume"_s), QByteArray("fr-a"));
        QVERIFY(QDir(toData + u"/BT_backup"_s).entryList({u"*.fluxtmp"_s}, QDir::Files).isEmpty());
        QVERIFY(!QFileInfo::exists(toConfig + u"/categories.json.fluxtmp"_s));
    }

    void missingSourceFails() const
    {
        QTemporaryDir dst;
        QVERIFY(dst.isValid());
        const Flux::QbtProfileLocation nowhere {Path(dst.path() + u"/nocfg"_s), Path(dst.path() + u"/nodata"_s)};
        const auto result = Flux::migrateProfile(nowhere, Path(dst.path() + u"/c"_s), Path(dst.path() + u"/d"_s), false);
        QVERIFY(!result.ok);
        QVERIFY(!result.error.isEmpty());
    }

    void processDetection() const
    {
        const QString ownName = QFileInfo(QCoreApplication::applicationFilePath()).fileName();
        QVERIFY(Flux::isProcessRunning(ownName));
        QVERIFY(Flux::isProcessRunning(ownName.toUpper())); // case-insensitive
        QVERIFY(!Flux::isProcessRunning(QUuid::createUuid().toString(QUuid::Id128) + u".exe"_s));
        // the real answer depends on the machine; it just must not misbehave
        Q_UNUSED(Flux::isQbittorrentRunning());
    }

    void fluxProfileName() const
    {
        // Keeps the test profile out of the real %APPDATA%: Profile creates its directories
        QStandardPaths::setTestModeEnabled(true);
        const QString previousName = QCoreApplication::applicationName();
        QCoreApplication::setApplicationName(Flux::applicationName());

        Profile::initInstance(Path(), QString(), false);
        const Path config = Profile::instance()->location(SpecialFolder::Config);
        const Path data = Profile::instance()->location(SpecialFolder::Data);
        const QString profileName = Profile::instance()->profileName();
        Profile::freeInstance();
        QCoreApplication::setApplicationName(previousName);
        QStandardPaths::setTestModeEnabled(false);

        QCOMPARE(profileName, u"Flux"_s);
        QVERIFY2(config.data().endsWith(u"/Flux"_s), qUtf8Printable(config.data()));
        QVERIFY2(data.data().endsWith(u"/Flux"_s), qUtf8Printable(data.data()));
    }
};

QTEST_MAIN(TestProfileMigrator)
#include "testprofilemigrator.moc"
