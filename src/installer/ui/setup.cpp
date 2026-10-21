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

#include "setup.h"

#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <tlhelp32.h>

#include <algorithm>

#include <QCoreApplication>
#include <QDate>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>

using namespace Qt::Literals::StringLiterals;

namespace
{
    const QString UNINSTALL_KEY = u"HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\FluxTorrent"_s;
    const QString CLASSES_KEY = u"HKEY_CURRENT_USER\\Software\\Classes"_s;
    const QString APP_KEY = u"HKEY_CURRENT_USER\\Software\\FluxTorrent"_s;
    const QString REGISTERED_APPS_KEY = u"HKEY_CURRENT_USER\\Software\\RegisteredApplications"_s;
    const QString TORRENT_PROG_ID = u"FluxTorrent.Torrent"_s;
    const QString MAGNET_PROG_ID = u"FluxTorrent.Magnet"_s;
    const QString MANIFEST = u".flux-install.json"_s;
    const QString FLUX_EXE = u"Flux.exe"_s;
    const QString SETUP_EXE = u"FluxSetup.exe"_s;
    const QString SHORTCUT_NAME = u"Flux Torrent.lnk"_s;
    const QString REPOSITORY_URL = QStringLiteral("https://github.com/" FLUX_GITHUB_REPO);

    Setup::Options g_options;

    QString nativePath(const QString &path)
    {
        return QDir::toNativeSeparators(QDir::cleanPath(path));
    }

    bool samePath(const QString &a, const QString &b)
    {
        return QDir::cleanPath(a).compare(QDir::cleanPath(b), Qt::CaseInsensitive) == 0;
    }

    QStringList filesUnder(const QString &root)
    {
        QStringList files;
        QDirIterator it {root, QDir::Files | QDir::Hidden | QDir::System, QDirIterator::Subdirectories};
        const QDir base {root};
        while (it.hasNext())
            files.append(base.relativeFilePath(it.next()));
        files.sort(Qt::CaseInsensitive);
        return files;
    }

    QStringList manifestFiles(const QString &dir)
    {
        QFile file {QDir(dir).filePath(MANIFEST)};
        if (!file.open(QIODevice::ReadOnly))
            return {};
        QStringList files;
        for (const QJsonValue &v : QJsonDocument::fromJson(file.readAll()).object().value(u"files"_s).toArray())
            files.append(v.toString());
        return files;
    }

    bool removeFile(const QString &path)
    {
        // a shortcut counts as a link: it is there even when what it points to is gone
        const QFileInfo info {path};
        if (!info.exists() && !info.isSymLink())
            return true;
        for (int attempt = 0; attempt < 10; ++attempt)
        {
            QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner);
            if (QFile::remove(path))
                return true;
            ::Sleep(150);
        }
        return false;
    }

    // Removes the folders under `root` (deepest first) that are empty, and `root` too if it ends up empty
    void removeEmptyFolders(const QString &root)
    {
        QStringList dirs;
        QDirIterator it {root, QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden, QDirIterator::Subdirectories};
        while (it.hasNext())
            dirs.append(it.next());
        std::sort(dirs.begin(), dirs.end(), [](const QString &a, const QString &b) { return a.size() > b.size(); });
        for (const QString &dir : std::as_const(dirs))
            QDir().rmdir(dir);
        QDir().rmdir(root);
    }

    bool createShortcut(const QString &linkPath, const QString &target, const QString &description)
    {
        IShellLinkW *link = nullptr;
        if (FAILED(::CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link))))
            return false;
        const std::wstring exe = nativePath(target).toStdWString();
        const std::wstring dir = nativePath(QFileInfo(target).absolutePath()).toStdWString();
        link->SetPath(exe.c_str());
        link->SetWorkingDirectory(dir.c_str());
        link->SetDescription(description.toStdWString().c_str());
        link->SetIconLocation(exe.c_str(), 0);
        IPersistFile *file = nullptr;
        bool ok = false;
        if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&file))))
        {
            ok = SUCCEEDED(file->Save(nativePath(linkPath).toStdWString().c_str(), TRUE));
            file->Release();
        }
        link->Release();
        return ok;
    }

    QString startMenuShortcut()
    {
        return QDir(QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation)).filePath(SHORTCUT_NAME);
    }

    // A string value of HKEY_CURRENT_USER\<subKey>, "" if there is none (reading never creates the key, as
    // QSettings would)
    QString readValue(const wchar_t *subKey, const wchar_t *name)
    {
        wchar_t buffer[2048] = {};
        DWORD size = sizeof(buffer);
        if (::RegGetValueW(HKEY_CURRENT_USER, subKey, name, RRF_RT_REG_SZ | RRF_RT_DWORD, nullptr, buffer, &size) != ERROR_SUCCESS)
            return {};
        return QString::fromWCharArray(buffer);
    }

    // Deletes a key of HKEY_CURRENT_USER with everything under it
    void deleteKey(const QString &subKey)
    {
        ::RegDeleteTreeW(HKEY_CURRENT_USER, subKey.toStdWString().c_str());
        ::RegDeleteKeyW(HKEY_CURRENT_USER, subKey.toStdWString().c_str());
    }

    QString desktopShortcut()
    {
        return QDir(QStandardPaths::writableLocation(QStandardPaths::DesktopLocation)).filePath(SHORTCUT_NAME);
    }

    // The nearest folder of `path` that exists (the target may not, yet)
    QString existingAncestor(const QString &path)
    {
        QFileInfo info {path};
        while (!info.exists() && !info.isRoot())
        {
            const QString parent = info.absolutePath();
            if (samePath(parent, info.absoluteFilePath()))
                break;
            info.setFile(parent);
        }
        return info.absoluteFilePath();
    }

    bool canWriteIn(const QString &folder)
    {
        QFile probe {QDir(folder).filePath(u".flux-setup-probe"_s)};
        if (!probe.open(QIODevice::WriteOnly))
            return false;
        probe.close();
        probe.remove();
        return true;
    }
}

void Setup::configure(const Options &options)
{
    g_options = options;
}

Setup *Setup::create(QQmlEngine *, QJSEngine *)
{
    static Setup *setup = new Setup(QCoreApplication::instance());
    QJSEngine::setObjectOwnership(setup, QJSEngine::CppOwnership);
    return setup;
}

Setup::Setup(QObject *parent)
    : QObject(parent)
    , m_mode {g_options.mode}
    , m_source {g_options.source.isEmpty() ? QCoreApplication::applicationDirPath() : g_options.source}
    , m_language {g_options.language.isEmpty() ? systemLanguage() : g_options.language}
    , m_fluxPid {g_options.fluxPid}
{
    const wchar_t *uninstallKey = L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\FluxTorrent";
    m_installedVersion = readValue(uninstallKey, L"DisplayVersion");
    const QString installed = readValue(uninstallKey, L"InstallLocation");

    if (!g_options.targetDir.isEmpty())
        m_targetDir = QDir::cleanPath(g_options.targetDir);
    else if (m_mode == u"uninstall")
        m_targetDir = QCoreApplication::applicationDirPath();
    else if (!installed.isEmpty())
        m_targetDir = QDir::cleanPath(installed);
    else
        m_targetDir = defaultTargetDir();

    // an update keeps what the user chose when installing
    if (!m_installedVersion.isEmpty())
    {
        const QFileInfo desktop {desktopShortcut()};
        m_desktopShortcut = desktop.exists() || desktop.isSymLink();
        m_associateTorrents = readValue(L"Software\\FluxTorrent", L"AssociateTorrents") != u"false";
        m_associateMagnets = readValue(L"Software\\FluxTorrent", L"AssociateMagnets") != u"false";
    }

    for (const QString &file : filesUnder(m_source))
        m_required += QFileInfo(QDir(m_source).filePath(file)).size();
}

Setup::~Setup()
{
    if (m_worker.joinable())
        m_worker.join();
}

QString Setup::mode() const { return m_mode; }
QString Setup::version() const { return QStringLiteral(FLUX_VERSION); }
QString Setup::installedVersion() const { return m_installedVersion; }
QString Setup::language() const { return m_language; }
QString Setup::targetDir() const { return nativePath(m_targetDir); }
qint64 Setup::requiredBytes() const { return m_required; }
QString Setup::state() const { return m_state; }
double Setup::progress() const { return m_progress; }
QString Setup::currentFile() const { return m_currentFile; }
QString Setup::error() const { return m_error; }

void Setup::setLanguage(const QString &language)
{
    if (language == m_language)
        return;
    m_language = language;
    emit languageChanged();
}

void Setup::setTargetDir(const QString &dir)
{
    const QString clean = QDir::cleanPath(QDir::fromNativeSeparators(dir.trimmed()));
    if (clean == m_targetDir)
        return;
    m_targetDir = clean;
    emit targetChanged();
}

qint64 Setup::freeBytes() const
{
    return QStorageInfo(existingAncestor(m_targetDir)).bytesAvailable();
}

QString Setup::targetProblem() const
{
    if (m_mode != u"install")
        return {};
    if (QDir::isRelativePath(m_targetDir) || (m_targetDir.size() < 4))
        return u"relative"_s;
    const QDir dir {m_targetDir};
    const bool isFlux = dir.exists(FLUX_EXE) || dir.exists(MANIFEST);
    if (dir.exists() && !isFlux && !dir.isEmpty(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden))
        return u"notEmpty"_s;
    if (!canWriteIn(existingAncestor(m_targetDir)))
        return u"notWritable"_s;
    if (freeBytes() < m_required)
        return u"noSpace"_s;
    return {};
}

QString Setup::defaultTargetDir()
{
    // a per-user install, like other apps that update themselves: no administrator rights needed
    return QDir::cleanPath(qEnvironmentVariable("LOCALAPPDATA") + u"/Programs/Flux Torrent"_s);
}

QString Setup::systemLanguage()
{
    static const QStringList codes {u"en"_s, u"ru"_s, u"uk"_s, u"de"_s, u"es"_s, u"fr"_s, u"pt_BR"_s, u"pl"_s, u"zh_CN"_s};
    for (const QString &wanted : QLocale::system().uiLanguages())
    {
        const QLocale locale {wanted};
        if (locale.language() == QLocale::Chinese)
        {
            if ((locale.script() != QLocale::TraditionalChineseScript) && (locale.territory() != QLocale::Taiwan)
                && (locale.territory() != QLocale::HongKong))
            {
                return u"zh_CN"_s;
            }
            continue;
        }
        if (locale.language() == QLocale::Portuguese)
            return u"pt_BR"_s;
        for (const QString &code : codes)
        {
            if (QLocale(code).language() == locale.language())
                return code;
        }
    }
    return u"en"_s;
}

void Setup::browse()
{
    IFileOpenDialog *dialog = nullptr;
    if (FAILED(::CoCreateInstance(CLSID_FileOpenDialog, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dialog))))
        return;
    DWORD flags = 0;
    dialog->GetOptions(&flags);
    dialog->SetOptions(flags | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST);
    IShellItem *start = nullptr;
    const std::wstring current = nativePath(existingAncestor(m_targetDir)).toStdWString();
    if (SUCCEEDED(::SHCreateItemFromParsingName(current.c_str(), nullptr, IID_PPV_ARGS(&start))))
    {
        dialog->SetFolder(start);
        start->Release();
    }
    if (SUCCEEDED(dialog->Show(::GetActiveWindow())))
    {
        IShellItem *item = nullptr;
        if (SUCCEEDED(dialog->GetResult(&item)))
        {
            PWSTR path = nullptr;
            if (SUCCEEDED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)))
            {
                QString chosen = QDir::fromNativeSeparators(QString::fromWCharArray(path));
                ::CoTaskMemFree(path);
                // a folder with other things in it gets Flux in a folder of its own
                const QDir dir {chosen};
                const bool isFlux = dir.exists(FLUX_EXE) || dir.exists(MANIFEST);
                if (!isFlux && !dir.isEmpty(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden))
                    chosen = dir.filePath(u"Flux Torrent"_s);
                setTargetDir(chosen);
            }
            item->Release();
        }
    }
    dialog->Release();
}

void Setup::setState(const QString &state, const QString &error)
{
    m_state = state;
    m_error = error;
    emit stateChanged();
}

QList<quint32> Setup::runningFlux() const
{
    QList<quint32> pids;
    HANDLE snapshot = ::CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE)
        return pids;
    PROCESSENTRY32W entry {sizeof(entry)};
    for (BOOL more = ::Process32FirstW(snapshot, &entry); more; more = ::Process32NextW(snapshot, &entry))
    {
        if (_wcsicmp(entry.szExeFile, L"Flux.exe") != 0)
            continue;
        HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, entry.th32ProcessID);
        if (!process)
            continue;
        wchar_t image[MAX_PATH * 4] = {};
        DWORD size = MAX_PATH * 4;
        if (::QueryFullProcessImageNameW(process, 0, image, &size)
            && samePath(QFileInfo(QString::fromWCharArray(image, size)).absolutePath(), m_targetDir))
        {
            pids.append(entry.th32ProcessID);
        }
        ::CloseHandle(process);
    }
    ::CloseHandle(snapshot);
    return pids;
}

bool Setup::waitForFlux()
{
    // the Flux that asked for this update is quitting (it saves its torrents' state first)
    if (m_fluxPid > 0)
    {
        if (HANDLE process = ::OpenProcess(SYNCHRONIZE, FALSE, static_cast<DWORD>(m_fluxPid)))
        {
            ::WaitForSingleObject(process, 120000);
            ::CloseHandle(process);
        }
        m_fluxPid = 0;
    }
    for (int i = 0; i < 20; ++i)
    {
        if (runningFlux().isEmpty())
            return true;
        ::Sleep(250);
    }
    return false;
}

void Setup::closeFlux()
{
    const QList<quint32> pids = runningFlux();
    ::EnumWindows([](HWND hwnd, LPARAM data) -> BOOL
    {
        const auto *list = reinterpret_cast<const QList<quint32> *>(data);
        DWORD pid = 0;
        ::GetWindowThreadProcessId(hwnd, &pid);
        if (list->contains(pid) && ::IsWindowVisible(hwnd))
            ::PostMessageW(hwnd, WM_CLOSE, 0, 0);
        return TRUE;
    }, reinterpret_cast<LPARAM>(&pids));
    // it quits on its own; start() waits for it
    start();
}

void Setup::start()
{
    if (m_state == u"working")
        return;
    if (m_worker.joinable())
        m_worker.join();
    m_progress = 0;
    m_currentFile.clear();
    setState(u"working"_s);
    emit progressChanged();

    m_worker = std::thread([this]
    {
        ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        if (m_mode == u"uninstall")
            uninstall();
        else
            install();
        ::CoUninitialize();
    });
}

void Setup::install()
{
    const auto report = [this](const QString &state, const QString &error = {})
    {
        QMetaObject::invokeMethod(this, [this, state, error] { setState(state, error); });
    };

    if (!waitForFlux())
    {
        report(u"fluxRunning"_s);
        return;
    }

    const QDir source {m_source};
    const QDir target {m_targetDir};
    if (!QDir().mkpath(m_targetDir))
    {
        report(u"failed"_s, nativePath(m_targetDir));
        return;
    }

    // the files, in chunks, so the bar moves through the big ones too
    const QStringList files = filesUnder(m_source);
    const QStringList oldFiles = manifestFiles(m_targetDir);
    qint64 done = 0;
    QByteArray buffer;
    buffer.resize(4 << 20);
    for (const QString &file : files)
    {
        QMetaObject::invokeMethod(this, [this, file] { m_currentFile = file; emit progressChanged(); });
        const QString to = target.filePath(file);
        QDir().mkpath(QFileInfo(to).absolutePath());
        removeFile(to);
        QFile in {source.filePath(file)};
        QSaveFile out {to};
        if (!in.open(QIODevice::ReadOnly) || !out.open(QIODevice::WriteOnly))
        {
            report(u"failed"_s, nativePath(to));
            return;
        }
        while (!in.atEnd())
        {
            const qint64 n = in.read(buffer.data(), buffer.size());
            if ((n < 0) || (out.write(buffer.constData(), n) != n))
            {
                report(u"failed"_s, nativePath(to));
                return;
            }
            done += n;
            m_progress = (m_required > 0) ? std::min(0.97, 0.97 * done / m_required) : 0.97;
            QMetaObject::invokeMethod(this, &Setup::progressChanged);
        }
        if (!out.commit())
        {
            report(u"failed"_s, nativePath(to));
            return;
        }
    }

    // what the old version had and this one has not
    const QSet<QString> current {files.cbegin(), files.cend()};
    for (const QString &old : oldFiles)
    {
        if (!current.contains(old) && !old.contains(u".."))
            removeFile(target.filePath(old));
    }
    removeEmptyFolders(m_targetDir);
    QDir().mkpath(m_targetDir);

    QJsonArray list;
    for (const QString &file : files)
        list.append(file);
    QSaveFile manifest {target.filePath(MANIFEST)};
    if (manifest.open(QIODevice::WriteOnly))
    {
        manifest.write(QJsonDocument(QJsonObject {{u"version"_s, version()}, {u"files"_s, list}}).toJson());
        manifest.commit();
    }

    // shortcuts
    const QString exe = target.filePath(FLUX_EXE);
    const QString description = u"Flux Torrent"_s;
    QDir().mkpath(QFileInfo(startMenuShortcut()).absolutePath());
    createShortcut(startMenuShortcut(), exe, description);
    if (m_desktopShortcut)
        createShortcut(desktopShortcut(), exe, description);
    else
        removeFile(desktopShortcut());

    // "Installed apps"
    QSettings uninstall {UNINSTALL_KEY, QSettings::NativeFormat};
    uninstall.setValue(u"DisplayName"_s, u"Flux Torrent"_s);
    uninstall.setValue(u"DisplayVersion"_s, version());
    uninstall.setValue(u"DisplayIcon"_s, nativePath(exe) + u",0"_s);
    uninstall.setValue(u"Publisher"_s, u"Flux contributors"_s);
    uninstall.setValue(u"InstallLocation"_s, nativePath(m_targetDir));
    uninstall.setValue(u"UninstallString"_s, u"\"%1\" --uninstall"_s.arg(nativePath(target.filePath(SETUP_EXE))));
    uninstall.setValue(u"URLInfoAbout"_s, REPOSITORY_URL);
    uninstall.setValue(u"HelpLink"_s, REPOSITORY_URL + u"/issues"_s);
    uninstall.setValue(u"URLUpdateInfo"_s, REPOSITORY_URL + u"/releases"_s);
    uninstall.setValue(u"InstallDate"_s, QDate::currentDate().toString(u"yyyyMMdd"_s));
    uninstall.setValue(u"EstimatedSize"_s, static_cast<int>(m_required / 1024));
    uninstall.setValue(u"NoModify"_s, 1);
    uninstall.setValue(u"NoRepair"_s, 1);
    uninstall.sync();

    // .torrent files and magnet links, and Flux in Windows' Default apps
    const QString open = u"\"%1\" \"%2\""_s.arg(nativePath(exe), u"%1"_s);
    const QString icon = nativePath(exe) + u",0"_s;
    QSettings classes {CLASSES_KEY, QSettings::NativeFormat};
    QSettings app {APP_KEY, QSettings::NativeFormat};
    app.setValue(u"AssociateTorrents"_s, m_associateTorrents);
    app.setValue(u"AssociateMagnets"_s, m_associateMagnets);
    app.setValue(u"Capabilities/ApplicationName"_s, u"Flux Torrent"_s);
    app.setValue(u"Capabilities/ApplicationDescription"_s, u"A torrent client with a built-in player"_s);
    app.setValue(u"Capabilities/ApplicationIcon"_s, icon);
    if (m_associateTorrents)
    {
        classes.setValue(TORRENT_PROG_ID + u"/Default"_s, u"Torrent file"_s);
        classes.setValue(TORRENT_PROG_ID + u"/DefaultIcon/Default"_s, icon);
        classes.setValue(TORRENT_PROG_ID + u"/shell/open/command/Default"_s, open);
        classes.setValue(u".torrent/Default"_s, TORRENT_PROG_ID);
        classes.setValue(u".torrent/Content Type"_s, u"application/x-bittorrent"_s);
        classes.setValue(u".torrent/OpenWithProgids/"_s + TORRENT_PROG_ID, QString());
        app.setValue(u"Capabilities/FileAssociations/.torrent"_s, TORRENT_PROG_ID);
    }
    if (m_associateMagnets)
    {
        classes.setValue(MAGNET_PROG_ID + u"/Default"_s, u"Magnet link"_s);
        classes.setValue(MAGNET_PROG_ID + u"/URL Protocol"_s, QString());
        classes.setValue(MAGNET_PROG_ID + u"/DefaultIcon/Default"_s, icon);
        classes.setValue(MAGNET_PROG_ID + u"/shell/open/command/Default"_s, open);
        classes.setValue(u"magnet/Default"_s, u"URL:Magnet link"_s);
        classes.setValue(u"magnet/URL Protocol"_s, QString());
        classes.setValue(u"magnet/DefaultIcon/Default"_s, icon);
        classes.setValue(u"magnet/shell/open/command/Default"_s, open);
        app.setValue(u"Capabilities/URLAssociations/magnet"_s, MAGNET_PROG_ID);
    }
    classes.sync();
    app.sync();
    QSettings registered {REGISTERED_APPS_KEY, QSettings::NativeFormat};
    registered.setValue(u"Flux Torrent"_s, u"Software\\FluxTorrent\\Capabilities"_s);
    registered.sync();
    ::SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);

    m_progress = 1;
    QMetaObject::invokeMethod(this, [this] { m_currentFile.clear(); emit progressChanged(); setState(u"done"_s); });
}

void Setup::uninstall()
{
    const auto report = [this](const QString &state, const QString &error = {})
    {
        QMetaObject::invokeMethod(this, [this, state, error] { setState(state, error); });
    };
    if (!waitForFlux())
    {
        report(u"fluxRunning"_s);
        return;
    }

    // the shortcuts first, while what they point to is still there
    removeFile(startMenuShortcut());
    removeFile(desktopShortcut());

    const QDir target {m_targetDir};
    const QStringList files = manifestFiles(m_targetDir);
    int i = 0;
    for (const QString &file : files)
    {
        // this program and the Qt it runs on stay until it quits (finish() removes them then)
        if (!file.contains(u"..") && !QFile::remove(target.filePath(file)) && QFileInfo::exists(target.filePath(file)))
            m_leftovers.append(file);
        m_progress = 0.8 * (++i) / std::max<qsizetype>(1, files.size());
        QMetaObject::invokeMethod(this, &Setup::progressChanged);
    }
    QFile::remove(target.filePath(MANIFEST));

    QSettings classes {CLASSES_KEY, QSettings::NativeFormat};
    if (classes.value(u".torrent/Default"_s).toString() == TORRENT_PROG_ID)
        classes.remove(u".torrent/Default"_s);
    classes.remove(u".torrent/OpenWithProgids/"_s + TORRENT_PROG_ID);
    const bool ourMagnet = classes.value(u"magnet/shell/open/command/Default"_s).toString()
        .contains(nativePath(target.filePath(FLUX_EXE)), Qt::CaseInsensitive);
    classes.sync();
    deleteKey(u"Software\\Classes\\"_s + TORRENT_PROG_ID);
    deleteKey(u"Software\\Classes\\"_s + MAGNET_PROG_ID);
    if (ourMagnet)
        deleteKey(u"Software\\Classes\\magnet"_s);
    QSettings registered {REGISTERED_APPS_KEY, QSettings::NativeFormat};
    registered.remove(u"Flux Torrent"_s);
    registered.sync();
    deleteKey(u"Software\\FluxTorrent"_s);
    deleteKey(u"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\FluxTorrent"_s);
    ::SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, nullptr, nullptr);

    // settings and the list of torrents, if asked (the downloaded files are not touched)
    if (m_removeUserData)
    {
        QDir(qEnvironmentVariable("APPDATA") + u"/Flux"_s).removeRecursively();
        QDir(qEnvironmentVariable("LOCALAPPDATA") + u"/Flux"_s).removeRecursively();
    }

    m_removeFolderOnExit = true;
    m_progress = 1;
    QMetaObject::invokeMethod(this, [this] { emit progressChanged(); setState(u"done"_s); });
}

void Setup::launchFlux()
{
    const QString exe = nativePath(QDir(m_targetDir).filePath(FLUX_EXE));
    std::wstring command = L"\"" + exe.toStdWString() + L"\"";
    STARTUPINFOW si {sizeof(si)};
    PROCESS_INFORMATION pi {};
    const std::wstring dir = nativePath(m_targetDir).toStdWString();
    if (::CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, DETACHED_PROCESS, nullptr, dir.c_str(), &si, &pi))
    {
        // let it come up in front of this window
        ::AllowSetForegroundWindow(pi.dwProcessId);
        ::CloseHandle(pi.hThread);
        ::CloseHandle(pi.hProcess);
    }
}

void Setup::finish()
{
    if (m_removeFolderOnExit)
    {
        // this program and the Qt beside it are still in use: a script removes them once it has quit, then
        // the folders it leaves empty (nothing else there is touched)
        const QString script = QDir(QDir::tempPath()).filePath(u"flux-uninstall-%1.cmd"_s.arg(::GetCurrentProcessId()));
        QFile file {script};
        if (file.open(QIODevice::WriteOnly))
        {
            QByteArray text = "@echo off\r\nping 127.0.0.1 -n 3 > nul\r\n";
            const QDir target {m_targetDir};
            for (const QString &f : std::as_const(m_leftovers))
                text += "del /f /q \"" + nativePath(target.filePath(f)).toLocal8Bit() + "\" > nul 2>&1\r\n";
            QStringList dirs;
            QDirIterator it {m_targetDir, QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden, QDirIterator::Subdirectories};
            while (it.hasNext())
                dirs.append(it.next());
            std::sort(dirs.begin(), dirs.end(), [](const QString &a, const QString &b) { return a.size() > b.size(); });
            dirs.append(m_targetDir);
            for (const QString &d : std::as_const(dirs))
                text += "rmdir \"" + nativePath(d).toLocal8Bit() + "\" > nul 2>&1\r\n";
            text += "del /f /q \"%~f0\"\r\n";
            file.write(text);
            file.close();
            std::wstring command = L"cmd.exe /c \"" + nativePath(script).toStdWString() + L"\"";
            STARTUPINFOW si {sizeof(si)};
            PROCESS_INFORMATION pi {};
            if (::CreateProcessW(nullptr, command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi))
            {
                ::CloseHandle(pi.hThread);
                ::CloseHandle(pi.hProcess);
            }
        }
    }
    QCoreApplication::quit();
}
