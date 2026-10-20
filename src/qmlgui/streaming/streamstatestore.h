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

#include <QDateTime>
#include <QList>
#include <QString>

// What a stream changed on its torrent, recorded before the change
struct StreamRecord
{
    QString torrentId;
    int fileIndex = 0;
    bool wasStopped = false; // the stream started the torrent
    bool wasForced = false;  // the torrent was already force-started
    QDateTime openedAt;

    friend bool operator==(const StreamRecord &, const StreamRecord &) = default;
};

// streams.json: the torrents open streams have changed. A record is written before a stream touches its
// torrent and removed when the stream gives it back; records left after a crash are rolled back at the
// next start (restoreAll). Writes are atomic (QSaveFile).
class StreamStateStore
{
public:
    explicit StreamStateStore(QString filePath);

    QString filePath() const;
    QList<StreamRecord> records() const;

    // Adds or replaces the record of the same torrent and file
    bool add(const StreamRecord &record);
    bool remove(const QString &torrentId, int fileIndex);
    // Hands every record to `restore`, then forgets them all
    void restoreAll(const std::function<void (const StreamRecord &)> &restore);

private:
    void load();
    bool save() const;

    QString m_filePath;
    QList<StreamRecord> m_records;
};
