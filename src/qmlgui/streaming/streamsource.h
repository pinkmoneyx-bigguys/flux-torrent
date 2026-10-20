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
#include <QObject>
#include <QString>

// Bytes a StreamServer serves: a file that may still be downloading. available() says how much can be
// read right now from an offset; dataAvailable() fires when more may have arrived.
class StreamSource : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(StreamSource)

public:
    using QObject::QObject;

    virtual qint64 size() const = 0;
    // The file name, for the Content-Type
    virtual QString fileName() const = 0;
    // How many bytes from `offset` (at most `maxLength`) are on disk and can be read now
    virtual qint64 available(qint64 offset, qint64 maxLength) const = 0;
    // Reads bytes that available() reported; may return fewer on an I/O error
    virtual QByteArray read(qint64 offset, qint64 length) = 0;
    // A client reads at `offset`: the source can fetch ahead of it
    virtual void noteRead(qint64 offset) { Q_UNUSED(offset); }

signals:
    void dataAvailable();
};
