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

#include <cstdint>

// The payload of Flux's setup: appended to the stub, after its last byte.
//
//   header   "FLUXPAK1", u32 file count, u64 total unpacked size
//   files    for each: u16 path length, the path (UTF-8, '/' between folders), u64 size,
//            u64 packed size, u8 method (0 stored, 1 LZMS), then the packed bytes
//   trailer  u64 offset of the header in the file, "FLUXEND!"
//
// LZMS is Windows' own (the Compression API, Windows 8 and later), so the stub needs no library to unpack it.
namespace FluxPayload
{
    inline constexpr char MAGIC[8] = {'F', 'L', 'U', 'X', 'P', 'A', 'K', '1'};
    inline constexpr char END[8] = {'F', 'L', 'U', 'X', 'E', 'N', 'D', '!'};
    inline constexpr std::uint8_t STORED = 0;
    inline constexpr std::uint8_t LZMS = 1;
    inline constexpr int TRAILER_SIZE = 16;
}
