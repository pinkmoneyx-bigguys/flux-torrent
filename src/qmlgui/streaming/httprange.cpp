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

#include "httprange.h"

#include <algorithm>

#include <QList>

HttpRange parseHttpRange(const QByteArray &header, const qint64 size)
{
    HttpRange whole;
    whole.start = 0;
    whole.end = size - 1;

    const QByteArray value = header.trimmed();
    if (!value.startsWith("bytes="))
        return whole;

    const QByteArray first = value.mid(6).split(',').first().trimmed();
    const qsizetype dash = first.indexOf('-');
    if (dash < 0)
        return whole;

    const QByteArray from = first.left(dash).trimmed();
    const QByteArray to = first.mid(dash + 1).trimmed();
    bool okFrom = false;
    bool okTo = false;

    HttpRange range;
    range.present = true;
    if (from.isEmpty())
    {
        // suffix range: the last N bytes
        const qint64 suffix = to.toLongLong(&okTo);
        if (!okTo || (suffix < 0))
            return whole;
        if ((suffix == 0) || (size == 0))
        {
            range.satisfiable = false;
            return range;
        }
        range.start = std::max<qint64>(0, size - suffix);
        range.end = size - 1;
        return range;
    }

    range.start = from.toLongLong(&okFrom);
    if (!okFrom || (range.start < 0))
        return whole;
    if (to.isEmpty())
    {
        range.end = size - 1;
    }
    else
    {
        range.end = to.toLongLong(&okTo);
        if (!okTo || (range.end < range.start))
            return whole;
        range.end = std::min(range.end, size - 1);
    }

    if (range.start >= size)
        range.satisfiable = false;
    return range;
}
