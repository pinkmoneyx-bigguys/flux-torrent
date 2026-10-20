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
#include <QtTypes>

// A parsed "Range: bytes=..." header against a resource of known size (RFC 9110, single range).
struct HttpRange
{
    bool present = false;     // a usable bytes range was asked for (otherwise: the whole resource, 200)
    bool satisfiable = true;  // false: answer 416
    qint64 start = 0;
    qint64 end = -1;          // inclusive

    qint64 length() const { return end - start + 1; }
};

// `header` is the value of the Range header (empty when absent). Multiple ranges: the first one is used.
// A malformed header or another unit is ignored, as the RFC allows.
HttpRange parseHttpRange(const QByteArray &header, qint64 size);
