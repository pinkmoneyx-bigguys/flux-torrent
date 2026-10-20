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

#include "streammanager.h"

#include <QCoreApplication>
#include <QDir>
#include <QStandardPaths>
#include <QTimer>

#include "base/bittorrent/infohash.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/global.h"
#include "base/path.h"
#include "base/profile.h"
#include "base/settingsstorage.h"
#include "base/tag.h"
#include "streamserver.h"
#include "streamsession.h"
#include "streamstatestore.h"

namespace
{
    const QString MODE_KEY = u"Flux/Streaming/Mode"_s;

    QString modeName(const StreamMode mode)
    {
        switch (mode)
        {
        case StreamMode::Fast: return u"fast"_s;
        case StreamMode::Economy: return u"economy"_s;
        default: return u"smooth"_s;
        }
    }

    StreamMode modeFromName(const QString &name)
    {
        if (name == u"fast")
            return StreamMode::Fast;
        if (name == u"economy")
            return StreamMode::Economy;
        return StreamMode::Smooth;
    }

    QString storePath()
    {
        if (BitTorrent::Session::instance())
            return (specialFolderLocation(SpecialFolder::Data) / Path(u"streams.json"_s)).data();
        // tests: no profile, nothing to keep
        return QDir::temp().filePath(u"flux-streams-test.json"_s);
    }
}

StreamManager::StreamManager(QObject *parent)
    : QObject(parent)
    , m_store {std::make_unique<StreamStateStore>(storePath())}
{
    m_server = new StreamServer([this](const QString &key) -> StreamSource * { return session(key); }, this);

    if (const SettingsStorage *storage = SettingsStorage::instance())
        m_mode = modeFromName(storage->loadValue<QString>(MODE_KEY, u"smooth"_s));

    restoreLeftovers();
    discardLeftovers();
    connect(qApp, &QCoreApplication::aboutToQuit, this, &StreamManager::closeAll);

    // Development aid for end-to-end checks: FLUX_STREAM_PROBE=<torrentId>/<fileIndex> opens that stream a
    // few seconds after start and logs its URL and whether the torrent was stopped before (streams close at
    // exit, so a second run on the same profile shows the torrent stopped again)
    if (const QString probe = qEnvironmentVariable("FLUX_STREAM_PROBE"); !probe.isEmpty())
    {
        const QString torrentId = probe.section(u'/', 0, 0);
        const int fileIndex = probe.section(u'/', 1, 1).toInt();
        QTimer::singleShot(4000, this, [this, torrentId, fileIndex]
        {
            const auto *torrent = BitTorrent::Session::instance()->getTorrent(BitTorrent::TorrentID::fromString(torrentId));
            const bool stoppedBefore = torrent && torrent->isStopped();
            const QUrl url = open(torrentId, fileIndex);
            qInfo("FLUX_STREAM_PROBE url=%s error=%s stoppedBefore=%d running=%d store=%s", qUtf8Printable(url.toString())
                , qUtf8Printable(m_lastError), stoppedBefore ? 1 : 0, (torrent && !torrent->isStopped()) ? 1 : 0
                , qUtf8Printable(m_store->filePath()));
        });
    }
}

StreamManager::~StreamManager()
{
    closeAll();
}

StreamManager *StreamManager::create(QQmlEngine *, QJSEngine *)
{
    return new StreamManager;
}

void StreamManager::restoreLeftovers()
{
    const auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    m_store->restoreAll([session](const StreamRecord &record)
    {
        StreamSession::restoreTorrent(session->getTorrent(BitTorrent::TorrentID::fromString(record.torrentId)), record);
    });
}

namespace
{
    const QString CACHE_KEY = u"Flux/Streaming/CachePath"_s;
    QString g_cachePath;  // without a profile (tests)
}

QString StreamManager::cachePath()
{
    const SettingsStorage *storage = SettingsStorage::instance();
    const QString chosen = storage ? storage->loadValue<QString>(CACHE_KEY) : g_cachePath;
    if (!chosen.isEmpty())
        return chosen;
    return QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).filePath(u"Flux Watch"_s);
}

QString StreamManager::cachePathProperty() const
{
    return cachePath();
}

void StreamManager::setCachePath(const QString &path)
{
    QString value = path.trimmed();
    if (value.startsWith(u"file:", Qt::CaseInsensitive))
        value = QUrl(value).toLocalFile();
    if (value == cachePath())
        return;
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(CACHE_KEY, value);
    else
        g_cachePath = value;
    emit cachePathChanged();
}

bool StreamManager::isWatchOnly(const QString &torrentId) const
{
    const auto *session = BitTorrent::Session::instance();
    const BitTorrent::Torrent *torrent = session ? session->getTorrent(BitTorrent::TorrentID::fromString(torrentId)) : nullptr;
    return torrent && torrent->hasTag(Tag(WATCH_TAG.toString()));
}

void StreamManager::discard(const QString &torrentId)
{
    if (!isWatchOnly(torrentId))
        return;
    for (const QString &key : m_sessions.keys())
    {
        if (key.startsWith(torrentId + u'/'))
            close(torrentId, key.section(u'/', 1, 1).toInt());
    }
    BitTorrent::Session::instance()->removeTorrent(BitTorrent::TorrentID::fromString(torrentId)
        , BitTorrent::TorrentRemoveOption::RemoveContent);
}

void StreamManager::discardLeftovers()
{
    auto *session = BitTorrent::Session::instance();
    if (!session)
        return;
    const Tag tag {WATCH_TAG.toString()};
    for (const BitTorrent::Torrent *torrent : session->torrents())
    {
        if (torrent->hasTag(tag))
            session->removeTorrent(torrent->id(), BitTorrent::TorrentRemoveOption::RemoveContent);
    }
}

QString StreamManager::keyOf(const QString &torrentId, const int fileIndex)
{
    return torrentId + u'/' + QString::number(fileIndex);
}

StreamSession *StreamManager::session(const QString &key) const
{
    return m_sessions.value(key, nullptr);
}

QString StreamManager::mode() const
{
    return modeName(m_mode);
}

void StreamManager::setMode(const QString &mode)
{
    const StreamMode value = modeFromName(mode);
    if (value == m_mode)
        return;
    m_mode = value;
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(MODE_KEY, modeName(m_mode));
    for (StreamSession *s : std::as_const(m_sessions))
        s->setMode(m_mode);
    emit modeChanged();
}

int StreamManager::openCount() const
{
    return static_cast<int>(m_sessions.size());
}

QString StreamManager::lastError() const
{
    return m_lastError;
}

QUrl StreamManager::open(const QString &torrentId, const int fileIndex)
{
    const QString key = keyOf(torrentId, fileIndex);
    if (m_sessions.contains(key))
        return m_server->url(key);

    auto *btSession = BitTorrent::Session::instance();
    BitTorrent::Torrent *torrent = btSession ? btSession->getTorrent(BitTorrent::TorrentID::fromString(torrentId)) : nullptr;
    if (!torrent)
    {
        m_lastError = tr("The torrent is not in the list.");
        emit streamsChanged();
        return {};
    }
    if (!m_server->start())
    {
        m_lastError = tr("Could not start the local stream server.");
        emit streamsChanged();
        return {};
    }

    auto *stream = new StreamSession(torrent, fileIndex, m_store.get(), this);
    if (const QString error = stream->open(m_mode); !error.isEmpty())
    {
        delete stream;
        m_lastError = error;
        emit streamsChanged();
        return {};
    }
    m_sessions.insert(key, stream);
    m_lastError.clear();
    emit streamsChanged();
    return m_server->url(key);
}

void StreamManager::close(const QString &torrentId, const int fileIndex)
{
    StreamSession *stream = m_sessions.take(keyOf(torrentId, fileIndex));
    if (!stream)
        return;
    stream->close();
    stream->deleteLater();
    emit streamsChanged();
}

void StreamManager::closeAll()
{
    if (m_sessions.isEmpty())
        return;
    const auto sessions = m_sessions;
    m_sessions.clear();
    for (StreamSession *stream : sessions)
    {
        stream->close();
        stream->deleteLater();
    }
    emit streamsChanged();
}

void StreamManager::setBitrate(const QString &torrentId, const int fileIndex, const qint64 bytesPerSecond)
{
    if (StreamSession *stream = session(keyOf(torrentId, fileIndex)))
        stream->setBitrate(bytesPerSecond);
}

QVariantMap StreamManager::stats(const QString &torrentId, const int fileIndex, const qint64 fromByte) const
{
    const StreamSession *stream = session(keyOf(torrentId, fileIndex));
    return stream ? stream->stats(fromByte) : QVariantMap {};
}

bool StreamManager::enabledSkippedFile(const QString &torrentId, const int fileIndex) const
{
    const StreamSession *stream = session(keyOf(torrentId, fileIndex));
    return stream && stream->enabledSkippedFile();
}
