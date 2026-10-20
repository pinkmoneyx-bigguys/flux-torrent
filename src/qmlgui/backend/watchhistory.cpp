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

#include "watchhistory.h"

#include <algorithm>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

#include "base/bittorrent/session.h"
#include "base/global.h"
#include "base/path.h"
#include "base/profile.h"

WatchHistory::WatchHistory(const QString &filePath, QObject *parent)
    : QObject(parent)
    , m_filePath {filePath}
{
    m_writeTimer.setSingleShot(true);
    m_writeTimer.setInterval(5000);
    connect(&m_writeTimer, &QTimer::timeout, this, &WatchHistory::write);
    load();
}

WatchHistory::~WatchHistory()
{
    flush();
}

WatchHistory *WatchHistory::create(QQmlEngine *, QJSEngine *)
{
    // tests run without a session or profile: memory only
    const QString path = BitTorrent::Session::instance()
        ? (specialFolderLocation(SpecialFolder::Data) / Path(u"watch-history.json"_s)).data()
        : QString();
    return new WatchHistory(path);
}

int WatchHistory::revision() const
{
    return m_revision;
}

QString WatchHistory::keyOf(const QString &torrentId, const int fileIndex)
{
    // the same key as MediaLibraryModel's items
    return torrentId + u':' + QString::number(fileIndex);
}

void WatchHistory::save(const QString &key, const double position, const double duration)
{
    if (key.isEmpty() || (position < 0))
        return;

    Entry &entry = m_entries[key];
    entry.position = position;
    if (duration > 0)
        entry.duration = duration;
    entry.updated = QDateTime::currentDateTimeUtc();
    ++m_revision;
    emit changed();
    if (!m_writeTimer.isActive())
        m_writeTimer.start();
}

double WatchHistory::position(const QString &key) const
{
    return m_entries.value(key).position;
}

double WatchHistory::duration(const QString &key) const
{
    return m_entries.value(key).duration;
}

double WatchHistory::progress(const QString &key) const
{
    const Entry entry = m_entries.value(key);
    return (entry.duration > 0) ? std::clamp(entry.position / entry.duration, 0.0, 1.0) : 0.0;
}

double WatchHistory::resumePosition(const QString &key) const
{
    const Entry entry = m_entries.value(key);
    if (entry.position < RESUME_MIN_SECONDS)
        return 0;
    if ((entry.duration > 0) && (entry.position > (entry.duration * RESUME_MAX)))
        return 0;
    return entry.position;
}

void WatchHistory::clear(const QString &key)
{
    if (m_entries.remove(key) == 0)
        return;
    ++m_revision;
    emit changed();
    if (!m_writeTimer.isActive())
        m_writeTimer.start();
}

void WatchHistory::flush()
{
    if (m_writeTimer.isActive())
    {
        m_writeTimer.stop();
        write();
    }
}

void WatchHistory::load()
{
    if (m_filePath.isEmpty())
        return;
    QFile file {m_filePath};
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = root.begin(); it != root.end(); ++it)
    {
        const QJsonObject obj = it.value().toObject();
        Entry entry;
        entry.position = obj.value(u"position"_s).toDouble();
        entry.duration = obj.value(u"duration"_s).toDouble();
        entry.updated = QDateTime::fromString(obj.value(u"updated"_s).toString(), Qt::ISODate);
        if (entry.position >= 0)
            m_entries.insert(it.key(), entry);
    }
}

void WatchHistory::write()
{
    if (m_filePath.isEmpty())
        return;

    // the most recent MAX_ENTRIES only
    QList<QString> keys = m_entries.keys();
    std::sort(keys.begin(), keys.end(), [this](const QString &a, const QString &b)
    {
        return m_entries.value(a).updated > m_entries.value(b).updated;
    });
    while (keys.size() > MAX_ENTRIES)
        m_entries.remove(keys.takeLast());

    QJsonObject root;
    for (const QString &key : std::as_const(keys))
    {
        const Entry &e = m_entries[key];
        root.insert(key, QJsonObject {
            {u"position"_s, e.position},
            {u"duration"_s, e.duration},
            {u"updated"_s, e.updated.toString(Qt::ISODate)}
        });
    }
    QDir().mkpath(QFileInfo(m_filePath).absolutePath());
    QSaveFile file {m_filePath};
    if (file.open(QIODevice::WriteOnly))
    {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        file.commit();
    }
}
