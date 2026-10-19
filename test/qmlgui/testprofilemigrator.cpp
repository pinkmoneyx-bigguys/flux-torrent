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
#include <QFile>
#include <QFileInfo>
#include <QObject>
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
