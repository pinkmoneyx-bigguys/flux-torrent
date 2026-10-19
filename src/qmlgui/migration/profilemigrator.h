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

#include <functional>
#include <optional>

#include <QString>

#include "base/path.h"

// Flux keeps its own profile (%APPDATA%\Flux, %LOCALAPPDATA%\Flux, Flux.ini) and, on the first run,
// can carry over the torrents and settings of an installed qBittorrent.
namespace Flux
{
    // QCoreApplication::applicationName() of Flux: it names the profile directories and the settings file
    QString applicationName();

    struct QbtProfileLocation
    {
        Path configDir; // <appData>/qBittorrent: qBittorrent.ini, categories.json, ...
        Path dataDir;   // <localAppData>/qBittorrent: BT_backup, rss, ...
    };

    // Looks for <appData>/qBittorrent/qBittorrent.ini and <localAppData>/qBittorrent
    std::optional<QbtProfileLocation> findQbittorrentProfile(const Path &appData, const Path &localAppData);

    // The same lookup in the real %APPDATA% and %LOCALAPPDATA% of the current user
    std::optional<QbtProfileLocation> findQbittorrentProfile();

    // Number of torrents in the profile: the rows of torrents.db if qBittorrent keeps its resume data in
    // SQLite (-1 if the database cannot be read), otherwise the *.fastresume files of BT_backup
    int countTorrents(const QbtProfileLocation &profile);

    // Whether a process with this executable name (e.g. "qbittorrent.exe", case-insensitive) is running
    bool isProcessRunning(const QString &exeName);
    bool isQbittorrentRunning();
    // Tests only: the executable name isQbittorrentRunning() looks for ("qbittorrent.exe" by default),
    // so that they do not depend on whether qBittorrent happens to be running on the machine
    void setQbittorrentProcessName(const QString &exeName);

    struct MigrationResult
    {
        bool ok = false;
        int torrentsCopied = 0;
        // "target-not-empty" if Flux already has torrents or other data and `overwrite` is false;
        // otherwise a human-readable message that names the file that could not be copied
        QString error;
    };

    // Copies, leaving the qBittorrent profile untouched:
    //   <config>/qBittorrent.ini                                  -> <toConfig>/Flux.ini
    //   <config>/{categories.json, watched_folders.json, rss/**}  -> <toConfig>/...
    //   <config>/{qBittorrent-data.ini, qBittorrent-rss.ini}      -> <toConfig>/... (the names Flux reads)
    //   <data>/{BT_backup/**, rss/**, torrents.db[-wal|-shm]}     -> <toData>/...
    // Paths into the qBittorrent profile inside the copied .ini files are redirected to the Flux profile.
    // Every file is first copied next to its destination under a temporary name and the files are moved
    // into place only after all copies succeeded. If anything fails the target is put back exactly as it was
    // (replaced files included), so the migration can simply be tried again.
    // Existing data is never replaced unless `overwrite` is set. The exceptions are the .ini files, which
    // every Flux start may create: they are replaced after being kept as <name>.bak.
    MigrationResult migrateProfile(const QbtProfileLocation &from, const Path &toConfigDir, const Path &toDataDir,
                                   bool overwrite);

    // Tests only: called before a staged file is moved into place; returning false makes that move fail
    using RenameHook = std::function<bool(const QString &from, const QString &to)>;
    void setRenameHook(RenameHook hook);
}
