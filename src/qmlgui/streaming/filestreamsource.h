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

#include <QFile>

#include "streamsource.h"

// A complete file on disk as a StreamSource. setAvailableLimit() pretends only the first N bytes are
// there yet (tests of waiting for data); raising it emits dataAvailable().
class FileStreamSource final : public StreamSource
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(FileStreamSource)

public:
    explicit FileStreamSource(const QString &path, QObject *parent = nullptr);

    qint64 size() const override;
    QString fileName() const override;
    qint64 available(qint64 offset, qint64 maxLength) const override;
    QByteArray read(qint64 offset, qint64 length) override;
    void noteRead(qint64 offset) override;

    void setAvailableLimit(qint64 bytes);
    qint64 lastReadOffset() const;

private:
    QFile m_file;
    qint64 m_limit = -1;
    qint64 m_lastRead = -1;
};
