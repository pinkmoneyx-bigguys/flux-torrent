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

#include "streamstatestore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

#include "base/global.h"

StreamStateStore::StreamStateStore(QString filePath)
    : m_filePath {std::move(filePath)}
{
    load();
}

QString StreamStateStore::filePath() const
{
    return m_filePath;
}

QList<StreamRecord> StreamStateStore::records() const
{
    return m_records;
}

bool StreamStateStore::add(const StreamRecord &record)
{
    m_records.removeIf([&record](const StreamRecord &r)
    {
        return (r.torrentId == record.torrentId) && (r.fileIndex == record.fileIndex);
    });
    m_records.append(record);
    return save();
}

bool StreamStateStore::remove(const QString &torrentId, const int fileIndex)
{
    const qsizetype removed = m_records.removeIf([&](const StreamRecord &r)
    {
        return (r.torrentId == torrentId) && (r.fileIndex == fileIndex);
    });
    return (removed == 0) || save();
}

void StreamStateStore::restoreAll(const std::function<void (const StreamRecord &)> &restore)
{
    const QList<StreamRecord> pending = m_records;
    for (const StreamRecord &record : pending)
        restore(record);
    m_records.clear();
    save();
}

void StreamStateStore::load()
{
    m_records.clear();
    QFile file {m_filePath};
    if (!file.open(QIODevice::ReadOnly))
        return;

    // a damaged file is ignored: nothing can be rolled back from it
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isArray())
        return;

    for (const QJsonValue &value : doc.array())
    {
        const QJsonObject obj = value.toObject();
        StreamRecord record;
        record.torrentId = obj.value(u"torrentId"_s).toString();
        record.fileIndex = obj.value(u"fileIndex"_s).toInt();
        record.wasStopped = obj.value(u"wasStopped"_s).toBool();
        record.wasForced = obj.value(u"wasForced"_s).toBool();
        record.openedAt = QDateTime::fromString(obj.value(u"openedAt"_s).toString(), Qt::ISODate);
        if (!record.torrentId.isEmpty())
            m_records.append(record);
    }
}

bool StreamStateStore::save() const
{
    if (m_records.isEmpty())
        return !QFile::exists(m_filePath) || QFile::remove(m_filePath);

    QJsonArray array;
    for (const StreamRecord &r : m_records)
    {
        array.append(QJsonObject {
            {u"torrentId"_s, r.torrentId},
            {u"fileIndex"_s, r.fileIndex},
            {u"wasStopped"_s, r.wasStopped},
            {u"wasForced"_s, r.wasForced},
            {u"openedAt"_s, r.openedAt.toString(Qt::ISODate)}
        });
    }

    QDir().mkpath(QFileInfo(m_filePath).absolutePath());
    QSaveFile file {m_filePath};
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(QJsonDocument(array).toJson(QJsonDocument::Indented));
    return file.commit();
}
