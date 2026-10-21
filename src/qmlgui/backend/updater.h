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

#include <QByteArray>
#include <QDateTime>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QFile;
class QNetworkAccessManager;
class QNetworkReply;
class QProcess;

// Checks GitHub for a newer Flux: the latest published release of AppInfo::repository() (drafts and
// pre-releases are not offered), its version against this build's, and the file to download (an
// installer .exe first, then a .zip; otherwise the release page). Checks on request, or quietly at
// every start while autoCheck is on. The request goes through the app's download
// manager, so proxy settings apply.
//
// install() puts the new version in place of this one: it downloads the release's archive (checking its
// size and, when GitHub gives one, its SHA-256), unpacks it, starts a small PowerShell script and quits
// Flux. The script waits for Flux to exit, copies the new files over the program folder (elevated when
// that folder isn't writable, e.g. under Program Files) and starts the new Flux with the same options.
// An installer (.exe) release is simply run. Only a deployed Flux (its Qt beside it) installs itself:
// a developer build is offered the download.
class Updater : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Updater)
    QML_ELEMENT
    QML_SINGLETON

    // "idle", "checking", "upToDate", "available", "error"
    Q_PROPERTY(QString status READ status NOTIFY changed FINAL)
    Q_PROPERTY(QString error READ error NOTIFY changed FINAL)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed FINAL)
    Q_PROPERTY(QString releaseName READ releaseName NOTIFY changed FINAL)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY changed FINAL)
    Q_PROPERTY(QString downloadUrl READ downloadUrl NOTIFY changed FINAL)
    Q_PROPERTY(QString downloadName READ downloadName NOTIFY changed FINAL)
    Q_PROPERTY(qint64 downloadSize READ downloadSize NOTIFY changed FINAL)
    Q_PROPERTY(QString notes READ notes NOTIFY changed FINAL)
    Q_PROPERTY(QDateTime lastChecked READ lastChecked NOTIFY changed FINAL)
    Q_PROPERTY(bool autoCheck READ autoCheck WRITE setAutoCheck NOTIFY autoCheckChanged FINAL)
    // the newer version can be installed from the app
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY changed FINAL)
    // "", "downloading", "unpacking", "restarting", "failed"
    Q_PROPERTY(QString installState READ installState NOTIFY installChanged FINAL)
    // 0…1 while downloading, -1 when the size isn't known
    Q_PROPERTY(double installProgress READ installProgress NOTIFY installChanged FINAL)
    Q_PROPERTY(QString installError READ installError NOTIFY installChanged FINAL)

public:
    explicit Updater(QObject *parent = nullptr);

    QString status() const;
    QString error() const;
    QString latestVersion() const;
    QString releaseName() const;
    QString releaseUrl() const;
    QString downloadUrl() const;
    QString downloadName() const;
    qint64 downloadSize() const;
    QString notes() const;
    QDateTime lastChecked() const;
    bool autoCheck() const;
    void setAutoCheck(bool on);
    bool canInstall() const;
    QString installState() const;
    double installProgress() const;
    QString installError() const;

    // `quiet`: no error status when it fails (the start-up check)
    Q_INVOKABLE void check(bool quiet = false);
    // At start: checks (quietly) when autoCheck is on
    Q_INVOKABLE void checkIfDue();
    // The installer or archive in the browser, or the release page
    Q_INVOKABLE void openDownload() const;
    // Downloads and installs the newer version, then restarts into it (see above)
    Q_INVOKABLE void install();
    Q_INVOKABLE void cancelInstall();

    // The folder of an unpacked release that holds Flux.exe: `root` itself or one folder down, "" if none
    static QString findProgramDir(const QString &root);
    // The script that replaces the program files once Flux has quit
    static QString applyScript();

    // < 0, 0, > 0 like strcmp; "v1.2.10" > "1.2.9" > "1.2.9-beta" (a suffix is earlier than none)
    static int compareVersions(const QString &a, const QString &b);
    // A GitHub release object as {version, name, url, notes, draft, prerelease, downloadUrl, downloadName,
    // downloadSize, downloadDigest ("sha256:…" when GitHub has it)}
    static QVariantMap parseRelease(const QByteArray &json, const QString &kind = QStringLiteral("zip"));
    // How the Flux in `appDir` was put there: "setup" (the installer), "portable" (an archive with a profile
    // folder beside the program), "zip" (an archive)
    static QString installKind(const QString &appDir);

signals:
    void changed();
    void autoCheckChanged();
    // a newer version showed up (also after a quiet check)
    void updateAvailable(const QString &version);
    void installChanged();

private:
    void finish(const QString &status, const QString &error = {});
    void setInstallState(const QString &state, const QString &error = {});
    void downloaded();
    void unpacked(const QString &programDir);
    void startInstaller(const QString &path);
    // Runs `program` detached, elevated when asked to; false if it could not start (or was refused)
    static bool launch(const QString &program, const QString &arguments, bool elevated);
    void quitForUpdate();

    QString m_status = QStringLiteral("idle");
    QString m_error;
    QVariantMap m_release;
    QDateTime m_lastChecked;
    bool m_quiet = false;
    bool m_checkedThisRun = false;

    QString m_installState;
    QString m_installError;
    double m_installProgress = 0;
    QNetworkAccessManager *m_network = nullptr;
    QPointer<QNetworkReply> m_reply;
    QFile *m_file = nullptr;
    QPointer<QProcess> m_unpack;
    QString m_workDir;
};
