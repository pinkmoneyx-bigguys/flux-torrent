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

#include "format.h"

#include <QLocale>

#include "base/global.h"
#include "base/types.h"
#include "base/utils/misc.h"

Format::Format(QObject *parent)
    : QObject(parent)
{
}

QString Format::speed(const qint64 bytesPerSec) const
{
    if (bytesPerSec == 0)
        return u"—"_s;

    return Utils::Misc::friendlyUnit(bytesPerSec, true);
}

QString Format::size(const qint64 bytes) const
{
    if (bytes < 0)
        return u"—"_s;

    return Utils::Misc::friendlyUnit(bytes);
}

QString Format::eta(const qint64 secs) const
{
    if ((secs < 0) || (secs >= MAX_ETA))
        return u"∞"_s;

    return Utils::Misc::userFriendlyDuration(secs);
}

QString Format::ratio(const qreal r) const
{
    if ((r < 0) || (r > 9999))
        return u"∞"_s;

    // the UI language's formats (Languages::effectiveLocale, set as the default)
    return QLocale().toString(r, 'f', 2);
}
