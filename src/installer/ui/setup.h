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

#pragma once

#include <atomic>
#include <thread>

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

// What the setup does, for its QML: installs Flux for the current user (no administrator rights) into a folder
// of their choice, updates an installed Flux in place (from Flux's own updater), or removes it.
//
// Installing copies the unpacked files (--source, the stub's temporary folder) into the folder, writes the list
// of them there (.flux-install.json: an update removes what the new version no longer has, the uninstaller
// knows what to delete), makes the Start menu and desktop shortcuts, registers Flux in "Installed apps", and
// opens .torrent files and magnet links with it if asked.
class Setup : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Setup)
    QML_ELEMENT
    QML_SINGLETON

    // "install", "update", "uninstall"
    Q_PROPERTY(QString mode READ mode CONSTANT FINAL)
    Q_PROPERTY(QString version READ version CONSTANT FINAL)
    // the version already installed for this user, "" if none
    Q_PROPERTY(QString installedVersion READ installedVersion CONSTANT FINAL)
    // the UI language: a code of Flux's languages (en, ru, uk, de, es, fr, pt_BR, pl, zh_CN)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged FINAL)

    Q_PROPERTY(QString targetDir READ targetDir WRITE setTargetDir NOTIFY targetChanged FINAL)
    Q_PROPERTY(qint64 requiredBytes READ requiredBytes CONSTANT FINAL)
    Q_PROPERTY(qint64 freeBytes READ freeBytes NOTIFY targetChanged FINAL)
    // "" when the folder can take Flux, else why not ("notEmpty", "notWritable", "noSpace", "relative")
    Q_PROPERTY(QString targetProblem READ targetProblem NOTIFY targetChanged FINAL)

    Q_PROPERTY(bool desktopShortcut MEMBER m_desktopShortcut NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool associateTorrents MEMBER m_associateTorrents NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool associateMagnets MEMBER m_associateMagnets NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool removeUserData MEMBER m_removeUserData NOTIFY optionsChanged FINAL)

    // "idle", "working", "fluxRunning", "done", "failed"
    Q_PROPERTY(QString state READ state NOTIFY stateChanged FINAL)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged FINAL)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY progressChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged FINAL)

public:
    struct Options
    {
        QString mode = QStringLiteral("install");
        QString source;     // the unpacked files
        QString targetDir;  // --dir
        QString language;   // --lang
        qint64 fluxPid = 0; // --pid: the Flux that asked for the update, to wait for
    };

    static void configure(const Options &options);
    static Setup *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    QString mode() const;
    QString version() const;
    QString installedVersion() const;
    QString language() const;
    void setLanguage(const QString &language);
    QString targetDir() const;
    void setTargetDir(const QString &dir);
    qint64 requiredBytes() const;
    qint64 freeBytes() const;
    QString targetProblem() const;
    QString state() const;
    double progress() const;
    QString currentFile() const;
    QString error() const;

    // The folder picker of Windows
    Q_INVOKABLE void browse();
    // Installs, updates or removes, by the mode
    Q_INVOKABLE void start();
    // Closes the Flux that keeps the setup waiting, then goes on
    Q_INVOKABLE void closeFlux();
    // Opens the installed Flux
    Q_INVOKABLE void launchFlux();
    // Ends the setup (after removing Flux: once this program has quit, its folder goes too)
    Q_INVOKABLE void finish();

    static QString defaultTargetDir();
    static QString systemLanguage();

signals:
    void languageChanged();
    void targetChanged();
    void optionsChanged();
    void stateChanged();
    void progressChanged();

private:
    explicit Setup(QObject *parent = nullptr);
    ~Setup() override;

    void setState(const QString &state, const QString &error = {});
    void install();
    void uninstall();
    // Flux.exe processes running from the target folder
    QList<quint32> runningFlux() const;
    bool waitForFlux();

    QString m_mode;
    QString m_source;
    QString m_targetDir;
    QString m_language;
    QString m_installedVersion;
    qint64 m_fluxPid = 0;
    qint64 m_required = 0;
    bool m_desktopShortcut = true;
    bool m_associateTorrents = true;
    bool m_associateMagnets = true;
    bool m_removeUserData = false;

    QString m_state = QStringLiteral("idle");
    QString m_error;
    std::atomic<double> m_progress {0};
    QString m_currentFile;
    std::thread m_worker;
    bool m_removeFolderOnExit = false;
    // Flux's files the uninstaller could not remove yet (this program, the Qt it runs on): removed once it quits
    QStringList m_leftovers;
};
