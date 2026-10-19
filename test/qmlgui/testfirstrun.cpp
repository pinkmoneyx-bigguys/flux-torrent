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

#include <memory>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMetaObject>
#include <QObject>
#include <QQuickWindow>
#include <QSettings>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>
#include <QUuid>
#include <QtQml>

#include "base/global.h"
#include "base/logger.h"
#include "base/path.h"
#include "base/profile.h"
#include "base/settingsstorage.h"
#include "qmlgui/migration/firstrun.h"
#include "qmlgui/migration/profilemigrator.h"

// The Flux module is a static QML module: import its plugin so "import Flux" resolves
Q_IMPORT_QML_PLUGIN(FluxPlugin)

namespace
{
    const QString DONE_KEY = u"Flux/FirstRun/Done"_s;

    void writeFile(const QString &path, const QByteArray &content)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file {path};
        if (!file.open(QIODevice::WriteOnly))
            qFatal("Cannot write %s", qUtf8Printable(path));
        file.write(content);
    }

    QQuickWindow *dialogWindow()
    {
        const auto windows = QGuiApplication::allWindows();
        for (QWindow *window : windows)
        {
            if (auto *quickWindow = qobject_cast<QQuickWindow *>(window))
                return quickWindow;
        }
        return nullptr;
    }
}

// Drives the real first-run flow (nested event loop, QML dialog, migration) on the offscreen platform with
// a throw-away Flux profile and a fake qBittorrent profile found through APPDATA / LOCALAPPDATA.
class TestFirstRun final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestFirstRun)

public:
    TestFirstRun() = default;

private slots:
    void initTestCase()
    {
        QCoreApplication::setApplicationName(Flux::applicationName());
        Logger::initInstance();
    }

    void cleanupTestCase()
    {
        Flux::setQbittorrentProcessName(u"qbittorrent.exe"_s);
        Logger::freeInstance();
    }

    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        m_appData = m_dir->path() + u"/appdata"_s;
        m_localAppData = m_dir->path() + u"/local"_s;
        qputenv("APPDATA", m_appData.toLocal8Bit());
        qputenv("LOCALAPPDATA", m_localAppData.toLocal8Bit());

        Profile::initInstance(Path(m_dir->path() + u"/profile"_s), QString(), false);
        SettingsStorage::initInstance();
    }

    void cleanup()
    {
        SettingsStorage::freeInstance();
        Profile::freeInstance();
        m_dir.reset();
    }

    void alreadyDone() const
    {
        makeQbtProfile();
        SettingsStorage::instance()->storeValue(DONE_KEY, true);
        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::NotNeeded);
        QVERIFY(dialogWindow() == nullptr);
    }

    void noQbittorrentProfile() const
    {
        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::NotNeeded);
        QVERIFY(dialogWindow() == nullptr);
        QVERIFY(SettingsStorage::instance()->loadValue<bool>(DONE_KEY, false));
    }

    void startFresh() const
    {
        makeQbtProfile();
        QTimer::singleShot(300, [] { emitFromDialog("startFreshRequested"); });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::StartedFresh);
        QVERIFY(SettingsStorage::instance()->loadValue<bool>(DONE_KEY, false));
        QVERIFY(!QFileInfo::exists(fluxData() + u"/BT_backup"_s));
    }

    void closingTheWindowChangesNothing() const
    {
        makeQbtProfile();
        QTimer::singleShot(300, [] {
            QQuickWindow *window = dialogWindow();
            QVERIFY(window != nullptr);
            window->close();
        });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::Closed);
        QVERIFY(!SettingsStorage::instance()->loadValue<bool>(DONE_KEY, false));
        QVERIFY(!QFileInfo::exists(fluxData() + u"/BT_backup"_s));
    }

    void dialogShowsTheTorrentCount() const
    {
        makeQbtProfile();
        int count = -1;
        QTimer::singleShot(300, [&count] {
            QQuickWindow *window = dialogWindow();
            QVERIFY(window != nullptr);
            count = window->property("torrentCount").toInt();
            emitFromDialog("startFreshRequested");
        });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::StartedFresh);
        QCOMPARE(count, 2);
    }

    void migrate() const
    {
        Flux::setQbittorrentProcessName(QUuid::createUuid().toString(QUuid::Id128) + u".exe"_s);
        makeQbtProfile();
        QTimer::singleShot(300, [] { emitFromDialog("migrateRequested"); });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::Migrated);

        QVERIFY(QFileInfo::exists(fluxData() + u"/BT_backup/a.fastresume"_s));
        QVERIFY(QFileInfo::exists(fluxData() + u"/BT_backup/b.fastresume"_s));
        // the answer is in the copied Flux.ini, together with the qBittorrent settings
        QSettings ini {fluxConfig() + u"/Flux.ini"_s, QSettings::IniFormat};
        QVERIFY(ini.value(DONE_KEY).toBool());
        QCOMPARE(ini.value(u"BitTorrent/Session/Port"_s).toInt(), 6881);
        // SettingsStorage took over what is on disk and has nothing of its own left to write over it
        QVERIFY(SettingsStorage::instance()->loadValue<bool>(DONE_KEY, false));
        QCOMPARE(SettingsStorage::instance()->loadValue<int>(u"BitTorrent/Session/Port"_s, 0), 6881);
        QVERIFY(!SettingsStorage::instance()->save());
    }

    void migrateIsBlockedWhileQbittorrentRuns() const
    {
        // any running process will do: this test's own
        Flux::setQbittorrentProcessName(QFileInfo(QCoreApplication::applicationFilePath()).fileName());
        makeQbtProfile();
        bool running = false;
        QTimer::singleShot(300, [] { emitFromDialog("migrateRequested"); });
        QTimer::singleShot(800, [&running] {
            QQuickWindow *window = dialogWindow();
            QVERIFY(window != nullptr);
            running = window->property("qbtRunning").toBool();
            emitFromDialog("startFreshRequested");
        });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::StartedFresh);
        QVERIFY(running);
        QVERIFY(!QFileInfo::exists(fluxData() + u"/BT_backup"_s));
    }

    void migrateIsRefusedWhenFluxHasTorrents() const
    {
        Flux::setQbittorrentProcessName(QUuid::createUuid().toString(QUuid::Id128) + u".exe"_s);
        makeQbtProfile();
        writeFile(fluxData() + u"/BT_backup/mine.fastresume"_s, "mine");

        QString errorCode;
        QTimer::singleShot(300, [] { emitFromDialog("migrateRequested"); });
        QTimer::singleShot(1200, [&errorCode] {
            QQuickWindow *window = dialogWindow();
            QVERIFY(window != nullptr);
            errorCode = window->property("errorCode").toString();
            emitFromDialog("startFreshRequested");
        });

        QCOMPARE(Flux::runFirstRun(), Flux::FirstRunOutcome::StartedFresh);
        QCOMPARE(errorCode, u"target-not-empty"_s);
        QVERIFY(!QFileInfo::exists(fluxData() + u"/BT_backup/a.fastresume"_s));
        QVERIFY(QFileInfo::exists(fluxData() + u"/BT_backup/mine.fastresume"_s));
    }

private:
    QString fluxConfig() const { return Profile::instance()->location(SpecialFolder::Config).data(); }
    QString fluxData() const { return Profile::instance()->location(SpecialFolder::Data).data(); }

    static void emitFromDialog(const char *signal)
    {
        QQuickWindow *window = dialogWindow();
        QVERIFY(window != nullptr);
        QVERIFY(QMetaObject::invokeMethod(window, signal));
    }

    void makeQbtProfile() const
    {
        const QString config = m_appData + u"/qBittorrent"_s;
        const QString data = m_localAppData + u"/qBittorrent"_s;
        writeFile(config + u"/qBittorrent.ini"_s, "[BitTorrent]\r\nSession\\Port=6881\r\n");
        writeFile(data + u"/BT_backup/a.fastresume"_s, "fr-a");
        writeFile(data + u"/BT_backup/a.torrent"_s, "t-a");
        writeFile(data + u"/BT_backup/b.fastresume"_s, "fr-b");
        writeFile(data + u"/BT_backup/b.torrent"_s, "t-b");
    }

    std::unique_ptr<QTemporaryDir> m_dir;
    QString m_appData;
    QString m_localAppData;
};

int main(int argc, char *argv[])
{
    // No window may reach the user's screen, and no GPU is needed
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QUICK_BACKEND", "software");
    QGuiApplication app {argc, argv};
    TestFirstRun test;
    return QTest::qExec(&test, argc, argv);
}

#include "testfirstrun.moc"
