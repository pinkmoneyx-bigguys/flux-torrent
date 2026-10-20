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

#include "filestreamsource.h"

#include <algorithm>

#include <QFileInfo>

FileStreamSource::FileStreamSource(const QString &path, QObject *parent)
    : StreamSource(parent)
    , m_file {path}
{
    // a file that does not open reads as empty (size 0)
    [[maybe_unused]] const bool opened = m_file.open(QIODevice::ReadOnly);
}

qint64 FileStreamSource::size() const
{
    return m_file.size();
}

QString FileStreamSource::fileName() const
{
    return QFileInfo(m_file.fileName()).fileName();
}

qint64 FileStreamSource::available(const qint64 offset, const qint64 maxLength) const
{
    const qint64 end = (m_limit >= 0) ? std::min(m_limit, size()) : size();
    return std::clamp<qint64>(end - offset, 0, maxLength);
}

QByteArray FileStreamSource::read(const qint64 offset, const qint64 length)
{
    if (!m_file.seek(offset))
        return {};
    return m_file.read(length);
}

void FileStreamSource::noteRead(const qint64 offset)
{
    m_lastRead = offset;
}

void FileStreamSource::setAvailableLimit(const qint64 bytes)
{
    m_limit = bytes;
    emit dataAvailable();
}

qint64 FileStreamSource::lastReadOffset() const
{
    return m_lastRead;
}
