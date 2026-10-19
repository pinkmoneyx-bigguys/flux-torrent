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

namespace Flux
{
    enum class FirstRunOutcome
    {
        NotNeeded,    // the first run was answered earlier, or there is no qBittorrent profile to offer
        StartedFresh, // the user chose to start with a clean profile; startup goes on
        Migrated,     // the torrents and settings were copied: the caller restarts Flux on the new profile
        Closed        // the user closed the dialog without choosing: the caller exits, nothing was changed
    };

    // The first-run check: unless `Flux/FirstRun/Done` is set and if a qBittorrent profile exists, shows the
    // migration dialog in its own QML engine and waits for the answer in a nested event loop.
    // It needs the Profile and the SettingsStorage, and must run before the BitTorrent session exists.
    // On every outcome but Closed the answer is recorded in `Flux/FirstRun/Done`.
    FirstRunOutcome runFirstRun();
}
