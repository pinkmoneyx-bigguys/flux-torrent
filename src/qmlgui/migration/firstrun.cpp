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

#include "firstrun.h"

#include <memory>

#include <QCoreApplication>
#include <QEventLoop>
#include <QGuiApplication>
#include <QLocale>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QScopeGuard>
#include <QSettings>
#include <QTimer>
#include <QTranslator>
#include <QWindow>

#include "base/global.h"
#include "base/profile.h"
#include "base/settingsstorage.h"
#include "qmlgui/fluxshell.h"
#include "profilemigrator.h"

namespace
{
    const QString FIRST_RUN_DONE_KEY = u"Flux/FirstRun/Done"_s;

    // The QML dialog is only a view: this fills in its properties and reacts to its signals
    class FirstRunDialog final : public QObject
    {
        Q_OBJECT
        Q_DISABLE_COPY_MOVE(FirstRunDialog)

    public:
        FirstRunDialog(const Flux::QbtProfileLocation &qbt, const Path &toConfig, const Path &toData, QObject *window)
            : m_qbt {qbt}
            , m_toConfig {toConfig}
            , m_toData {toData}
            , m_window {window}
        {
            m_window->setProperty("torrentCount", Flux::countTorrents(qbt));
            updateRunning();

            connect(&m_pollTimer, &QTimer::timeout, this, &FirstRunDialog::updateRunning);
            m_pollTimer.start(1500);

            connect(m_window, SIGNAL(migrateRequested()), this, SLOT(onMigrateRequested()));
            connect(m_window, SIGNAL(startFreshRequested()), this, SLOT(onStartFreshRequested()));
            connect(qobject_cast<QWindow *>(m_window), &QWindow::visibleChanged, this, [this](const bool visible)
            {
                if (!visible && !m_decided)
                    finish(Choice::Closed);
            });
        }

        enum class Choice
        {
            Closed,
            StartFresh,
            Migrated
        };

        Choice exec()
        {
            m_loop.exec();
            return m_choice;
        }

    private slots:
        void onStartFreshRequested()
        {
            if (!m_busy)
                finish(Choice::StartFresh);
        }

        void onMigrateRequested()
        {
            if (m_busy)
                return;

            // Never copy while qBittorrent may still be writing its fast-resume data
            if (Flux::isQbittorrentRunning())
            {
                updateRunning();
                return;
            }

            m_busy = true;
            m_window->setProperty("errorCode", QString());
            m_window->setProperty("errorDetail", QString());
            m_window->setProperty("busy", true);
            // Let the "migrating" state reach the screen before the copy blocks the UI thread
            QTimer::singleShot(120, this, &FirstRunDialog::migrate);
        }

    private:
        void updateRunning()
        {
            m_window->setProperty("qbtRunning", Flux::isQbittorrentRunning());
        }

        void migrate()
        {
            const Flux::MigrationResult result = Flux::migrateProfile(m_qbt, m_toConfig, m_toData, false);
            m_busy = false;
            m_window->setProperty("busy", false);

            if (!result.ok)
            {
                const bool occupied = (result.error == u"target-not-empty"_s);
                m_window->setProperty("errorCode", occupied ? u"target-not-empty"_s : u"failed"_s);
                m_window->setProperty("errorDetail", occupied ? QString() : result.error);
                return;
            }

            // Flux.ini now is the copy of qBittorrent.ini: record the answer in it, then make
            // SettingsStorage forget its own, older state so that it does not overwrite the copy on exit
            {
                const std::unique_ptr<QSettings> settings = Profile::instance()->applicationSettings(Flux::applicationName());
                settings->setValue(FIRST_RUN_DONE_KEY, true);
                settings->sync();
            }
            SettingsStorage::instance()->reload();
            finish(Choice::Migrated);
        }

        void finish(const Choice choice)
        {
            if (m_decided)
                return;
            m_decided = true;
            m_choice = choice;
            m_pollTimer.stop();
            m_loop.quit();
        }

        Flux::QbtProfileLocation m_qbt;
        Path m_toConfig;
        Path m_toData;
        QObject *m_window = nullptr;
        QEventLoop m_loop;
        QTimer m_pollTimer;
        Choice m_choice = Choice::Closed;
        bool m_decided = false;
        bool m_busy = false;
    };
}

Flux::FirstRunOutcome Flux::runFirstRun()
{
    SettingsStorage *settings = SettingsStorage::instance();
    if (settings->loadValue<bool>(FIRST_RUN_DONE_KEY, false))
        return FirstRunOutcome::NotNeeded;

    const std::optional<QbtProfileLocation> qbt = findQbittorrentProfile();
    if (!qbt)
    {
        // Nothing to offer. Remember it, so that a qBittorrent installed later does not
        // turn up in a dialog months into using Flux.
        settings->storeValue(FIRST_RUN_DONE_KEY, true);
        return FirstRunOutcome::NotNeeded;
    }

    // The dialog is shown before the main shell exists: it needs the UI translation on its own
    QTranslator translator;
    if (FluxShell::loadTranslation(translator, QLocale::system()))
        QCoreApplication::installTranslator(&translator);
    // Closing the dialog must not make QGuiApplication quit by itself
    const bool quitOnLastWindowClosed = QGuiApplication::quitOnLastWindowClosed();
    QGuiApplication::setQuitOnLastWindowClosed(false);
    const auto restore = qScopeGuard([&translator, quitOnLastWindowClosed]
    {
        QGuiApplication::setQuitOnLastWindowClosed(quitOnLastWindowClosed);
        QCoreApplication::removeTranslator(&translator);
    });

    FirstRunDialog::Choice choice = FirstRunDialog::Choice::Closed;
    {
        QQmlApplicationEngine engine;
        engine.loadFromModule(u"Flux"_s, u"FirstRunWindow"_s);
        if (engine.rootObjects().isEmpty())
        {
            // The dialog is a courtesy: do not lock the user out of the application because of it
            qCritical("Failed to load the Flux.FirstRunWindow QML component.");
            return FirstRunOutcome::NotNeeded;
        }

        FirstRunDialog dialog {*qbt, Profile::instance()->location(SpecialFolder::Config),
                               Profile::instance()->location(SpecialFolder::Data), engine.rootObjects().constFirst()};
        choice = dialog.exec();
    }

    switch (choice)
    {
    case FirstRunDialog::Choice::StartFresh:
        settings->storeValue(FIRST_RUN_DONE_KEY, true);
        return FirstRunOutcome::StartedFresh;
    case FirstRunDialog::Choice::Migrated:
        return FirstRunOutcome::Migrated;
    case FirstRunDialog::Choice::Closed:
        break;
    }
    return FirstRunOutcome::Closed;
}

#include "firstrun.moc"
