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

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTimer>
#include <QUrl>

#ifdef Q_OS_WIN
#include <windows.h>
#include <shellapi.h>
#endif

#include "base/global.h"
#include "base/net/downloadmanager.h"
#include "base/settingsstorage.h"
#include "appinfo.h"

namespace
{
    const QString AUTO_CHECK_KEY = u"Flux/Updates/AutoCheck"_s;
    const QString LAST_CHECK_KEY = u"Flux/Updates/LastCheck"_s;
    const QString WORK_DIR_NAME = u"Flux-update"_s;
    const QString FAILED_FILE = u"failed.txt"_s;

    QString workDir()
    {
        return QDir(QDir::tempPath()).filePath(WORK_DIR_NAME);
    }

    // where to download from: GitHub over https, or (tests) a server on this computer
    bool trustedDownload(const QUrl &url)
    {
        return (url.scheme() == u"https") || ((url.scheme() == u"http") && (url.host() == u"127.0.0.1"));
    }

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

    // what an update left behind: the files of one that went in, or why one did not
    const QDir work {workDir()};
    if (SettingsStorage::instance() && work.exists())
    {
        QFile failed {work.filePath(FAILED_FILE)};
        if (failed.open(QIODevice::ReadOnly))
        {
            const QString code = QString::fromUtf8(failed.readAll()).trimmed();
            failed.close();
            m_installState = u"failed"_s;
            m_installError = tr("The last update could not replace the program files (robocopy code %1). The log is in %2.")
                .arg(code, QDir::toNativeSeparators(work.filePath(u"apply.log"_s)));
            failed.remove();
        }
        else
        {
            QDir(work).removeRecursively();
        }
    }
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
            map.insert(u"downloadDigest"_s, asset.value(u"digest"_s).toString());
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

bool Updater::canInstall() const
{
#ifdef Q_OS_WIN
    if ((m_status != u"available") || downloadUrl().isEmpty())
        return false;
    const QString name = downloadName().toLower();
    if (!name.endsWith(u".zip") && !name.endsWith(u".exe"))
        return false;
    // a deployed Flux has its Qt beside it; a developer build runs on the Qt of the build machine
    return QFileInfo::exists(QDir(QCoreApplication::applicationDirPath()).filePath(u"Qt6Core.dll"_s));
#else
    return false;
#endif
}

QString Updater::installState() const { return m_installState; }
double Updater::installProgress() const { return m_installProgress; }
QString Updater::installError() const { return m_installError; }

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
    // a quiet check that failed says nothing and does not count: the next start tries again
    if (m_quiet && (status == u"error"))
    {
        m_status = u"idle"_s;
        m_error.clear();
        emit changed();
        return;
    }
    m_status = status;
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

    // FLUX_UPDATE_API: another release to look at (testing the update on a server of one's own)
    const QString api = qEnvironmentVariable("FLUX_UPDATE_API");
    if (AppInfo::repository().isEmpty() && api.isEmpty())
    {
        finish(u"error"_s, tr("This build does not say where its releases are published."));
        return;
    }
    auto *manager = Net::DownloadManager::instance();
    if (!manager)
    {
        // at start the network may come up a moment after the window: a quiet check waits for it
        if (quiet)
            QTimer::singleShot(10000, this, [this] { check(true); });
        else
            finish(u"error"_s, tr("The network is not ready."));
        return;
    }

    m_status = u"checking"_s;
    m_error.clear();
    emit changed();

    const QString url = !api.isEmpty() ? api : u"https://api.github.com/repos/%1/releases/latest"_s.arg(AppInfo::repository());
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
    // once a start: a newer version (or the one just installed) is known as soon as Flux is up
    if (!autoCheck() || m_checkedThisRun)
        return;
    m_checkedThisRun = true;
    check(true);
}

void Updater::openDownload() const
{
    const QString url = downloadUrl().isEmpty() ? releaseUrl() : downloadUrl();
    const QUrl target {url};
    if (target.isValid() && (target.scheme() == u"https"))
        QDesktopServices::openUrl(target);
}

void Updater::setInstallState(const QString &state, const QString &error)
{
    m_installState = state;
    m_installError = error;
    emit installChanged();
}

void Updater::install()
{
    if (!canInstall() || (m_installState == u"downloading") || (m_installState == u"unpacking") || (m_installState == u"restarting"))
        return;
    const QUrl url {downloadUrl()};
    if (!trustedDownload(url))
    {
        setInstallState(u"failed"_s, tr("The download address is not a secure one."));
        return;
    }

    // a clean folder for this update
    m_workDir = workDir();
    QDir(m_workDir).removeRecursively();
    if (!QDir().mkpath(m_workDir))
    {
        setInstallState(u"failed"_s, tr("Cannot create %1.").arg(QDir::toNativeSeparators(m_workDir)));
        return;
    }
    m_file = new QFile(QDir(m_workDir).filePath(QFileInfo(downloadName()).fileName()), this);
    if (!m_file->open(QIODevice::WriteOnly))
    {
        setInstallState(u"failed"_s, tr("Cannot write %1.").arg(QDir::toNativeSeparators(m_file->fileName())));
        delete m_file;
        m_file = nullptr;
        return;
    }

    if (!m_network)
        m_network = new QNetworkAccessManager(this);
    QNetworkRequest request {url};
    request.setHeader(QNetworkRequest::UserAgentHeader, QString(u"Flux/"_s + AppInfo::version()));
    // GitHub sends release files from another host
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    m_reply = m_network->get(request);

    m_installProgress = (downloadSize() > 0) ? 0 : -1;
    setInstallState(u"downloading"_s);

    connect(m_reply, &QNetworkReply::readyRead, this, [this]
    {
        if (m_file && m_reply)
            m_file->write(m_reply->readAll());
    });
    connect(m_reply, &QNetworkReply::downloadProgress, this, [this](const qint64 received, const qint64 total)
    {
        const qint64 size = (total > 0) ? total : downloadSize();
        m_installProgress = (size > 0) ? std::clamp(double(received) / double(size), 0.0, 1.0) : -1;
        emit installChanged();
    });
    connect(m_reply, &QNetworkReply::finished, this, &Updater::downloaded);
}

void Updater::cancelInstall()
{
    if (m_installState == u"downloading")
    {
        if (m_reply)
            m_reply->abort();  // finished() follows, with OperationCanceledError
        return;
    }
    if ((m_installState == u"unpacking") && m_unpack)
    {
        m_unpack->kill();
        return;
    }
}

void Updater::downloaded()
{
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    reply->deleteLater();
    if (m_file)
    {
        m_file->write(reply->readAll());
        m_file->close();
    }
    const QString path = m_file ? m_file->fileName() : QString();
    delete m_file;
    m_file = nullptr;

    if (reply->error() == QNetworkReply::OperationCanceledError)
    {
        QDir(m_workDir).removeRecursively();
        setInstallState({});
        return;
    }
    if (reply->error() != QNetworkReply::NoError)
    {
        setInstallState(u"failed"_s, tr("The download failed: %1").arg(reply->errorString()));
        return;
    }

    // the file GitHub listed, whole and unchanged
    QFile file {path};
    if ((downloadSize() > 0) && (file.size() != downloadSize()))
    {
        file.remove();
        setInstallState(u"failed"_s, tr("The download is incomplete (%1 of %2 bytes).").arg(file.size()).arg(downloadSize()));
        return;
    }
    const QString digest = m_release.value(u"downloadDigest"_s).toString();
    if (digest.startsWith(u"sha256:", Qt::CaseInsensitive) && file.open(QIODevice::ReadOnly))
    {
        QCryptographicHash hash {QCryptographicHash::Sha256};
        hash.addData(&file);
        file.close();
        if (QString::fromLatin1(hash.result().toHex()).compare(digest.mid(7), Qt::CaseInsensitive) != 0)
        {
            file.remove();
            setInstallState(u"failed"_s, tr("The download is damaged: its checksum does not match the release."));
            return;
        }
    }

    if (path.endsWith(u".exe", Qt::CaseInsensitive))
    {
        startInstaller(path);
        return;
    }

    // unpack with Windows' own tar (it reads .zip)
    m_installProgress = -1;
    setInstallState(u"unpacking"_s);
    const QString stage = QDir(m_workDir).filePath(u"new"_s);
    QDir().mkpath(stage);
    m_unpack = new QProcess(this);
    const QString tar = QDir(qEnvironmentVariable("SystemRoot", u"C:/Windows"_s)).filePath(u"System32/tar.exe"_s);
    connect(m_unpack, &QProcess::finished, this, [this, stage](const int exitCode, const QProcess::ExitStatus exitStatus)
    {
        m_unpack->deleteLater();
        if ((exitStatus != QProcess::NormalExit) || (exitCode != 0))
        {
            setInstallState(u"failed"_s, tr("The downloaded archive could not be unpacked."));
            return;
        }
        const QString programDir = findProgramDir(stage);
        if (programDir.isEmpty())
        {
            setInstallState(u"failed"_s, tr("The archive has no Flux.exe in it."));
            return;
        }
        unpacked(programDir);
    });
    connect(m_unpack, &QProcess::errorOccurred, this, [this](const QProcess::ProcessError error)
    {
        if (error == QProcess::FailedToStart)
        {
            m_unpack->deleteLater();
            setInstallState(u"failed"_s, tr("The downloaded archive could not be unpacked."));
        }
    });
    m_unpack->start(tar, {u"-xf"_s, QDir::toNativeSeparators(path), u"-C"_s, QDir::toNativeSeparators(stage)});
}

QString Updater::findProgramDir(const QString &root)
{
    const QDir dir {root};
    if (dir.exists(u"Flux.exe"_s))
        return dir.absolutePath();
    const QStringList subdirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : subdirs)
    {
        if (QDir(dir.filePath(name)).exists(u"Flux.exe"_s))
            return QDir(dir.filePath(name)).absolutePath();
    }
    return {};
}

QString Updater::applyScript()
{
    return uR"ps(# Written by Flux to install an update: replaces the program files once Flux has quit, then starts it
param([int]$ProcessId, [string]$From, [string]$To, [string]$Log)

# Flux is quitting: wait for it (saving the torrents' state takes a moment), so its files can be replaced
$flux = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
if ($flux -and -not $flux.WaitForExit(120000)) {
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# the new version over the old one; a file still locked a moment is tried again
robocopy $From $To /E /R:20 /W:1 /NP /NJH /NJS "/LOG:$Log" | Out-Null
$code = $LASTEXITCODE

# again with the options Flux was started with (a profile folder, say)
$work = Split-Path -Parent $Log
$optionsFile = Join-Path $work 'options.txt'
$options = if (Test-Path -LiteralPath $optionsFile) { (Get-Content -LiteralPath $optionsFile -Raw -Encoding UTF8).Trim() } else { '' }
$exe = Join-Path $To 'Flux.exe'
if ($options -ne '') { Start-Process -FilePath $exe -WorkingDirectory $To -ArgumentList $options }
else { Start-Process -FilePath $exe -WorkingDirectory $To }

# robocopy: below 8 is success; otherwise Flux tells about it at its next start
if ($code -lt 8) { Get-ChildItem -LiteralPath $work -Exclude 'apply.log' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
else { Set-Content -LiteralPath (Join-Path $work 'failed.txt') -Value $code }
)ps"_s;
}

void Updater::unpacked(const QString &programDir)
{
    const QDir work {m_workDir};
    const QString scriptPath = work.filePath(u"apply-update.ps1"_s);
    {
        QSaveFile script {scriptPath};
        // with a BOM: Windows PowerShell reads a script without one in the ANSI code page
        if (!script.open(QIODevice::WriteOnly) || (script.write("\xEF\xBB\xBF" + applyScript().toUtf8()) < 0) || !script.commit())
        {
            setInstallState(u"failed"_s, tr("Cannot write %1.").arg(QDir::toNativeSeparators(scriptPath)));
            return;
        }
    }

    // the new Flux starts with this one's options (a profile folder, say), not with files or links
    QStringList options;
    for (const QString &arg : QCoreApplication::arguments().mid(1))
    {
        if (arg.startsWith(u"--"))
            options.append(arg.contains(u' ') ? (u'"' + arg + u'"') : arg);
    }
    // in a file: quotes inside powershell's -File arguments don't survive
    if (!options.isEmpty())
    {
        QSaveFile file {work.filePath(u"options.txt"_s)};
        if (file.open(QIODevice::WriteOnly))
        {
            file.write("\xEF\xBB\xBF" + options.join(u' ').toUtf8());
            file.commit();
        }
    }
    const auto quoted = [](const QString &path) { return u'"' + QDir::toNativeSeparators(path) + u'"'; };
    const QString arguments = u"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File %1 -ProcessId %2 -From %3 -To %4 -Log %5"_s
        .arg(quoted(scriptPath), QString::number(QCoreApplication::applicationPid()), quoted(programDir),
            quoted(QCoreApplication::applicationDirPath()), quoted(work.filePath(u"apply.log"_s)));

    // a program folder this user can't write to (Program Files) needs the administrator's rights
    QFile probe {QDir(QCoreApplication::applicationDirPath()).filePath(u".flux-update-probe"_s)};
    const bool writable = probe.open(QIODevice::WriteOnly);
    if (writable)
    {
        probe.close();
        probe.remove();
    }

    const QString powershell = QDir(qEnvironmentVariable("SystemRoot", u"C:/Windows"_s))
        .filePath(u"System32/WindowsPowerShell/v1.0/powershell.exe"_s);
    if (!launch(powershell, arguments, !writable))
    {
        setInstallState(u"failed"_s, writable ? tr("The installer could not start.")
                                              : tr("Installing needs the administrator's permission."));
        return;
    }
    quitForUpdate();
}

void Updater::startInstaller(const QString &path)
{
    if (!launch(path, {}, false))
    {
        setInstallState(u"failed"_s, tr("The installer could not start."));
        return;
    }
    quitForUpdate();
}

void Updater::quitForUpdate()
{
    m_installProgress = 1;
    setInstallState(u"restarting"_s);
    // a moment for the window to say so, then the normal exit (it saves the torrents' state)
    QTimer::singleShot(600, qApp, [] { QCoreApplication::quit(); });
}

bool Updater::launch(const QString &program, const QString &arguments, const bool elevated)
{
#ifdef Q_OS_WIN
    const std::wstring file = QDir::toNativeSeparators(program).toStdWString();
    const std::wstring params = arguments.toStdWString();
    SHELLEXECUTEINFOW info {};
    info.cbSize = sizeof(info);
    info.fMask = SEE_MASK_NOASYNC;
    info.lpVerb = elevated ? L"runas" : L"open";
    info.lpFile = file.c_str();
    info.lpParameters = params.empty() ? nullptr : params.c_str();
    info.nShow = SW_HIDE;
    return ::ShellExecuteExW(&info) != FALSE;
#else
    Q_UNUSED(program);
    Q_UNUSED(arguments);
    Q_UNUSED(elevated);
    return false;
#endif
}
