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

#include "sessionfacade.h"

#include <QList>

#include "base/bittorrent/session.h"
#include "base/bittorrent/sessionstatus.h"
#include "base/bittorrent/torrent.h"

SessionFacade::SessionFacade(QObject *parent)
    : QObject(parent)
{
    auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    connect(session, &BitTorrent::Session::statsUpdated, this, &SessionFacade::refresh);
    connect(session, &BitTorrent::Session::speedLimitModeChanged, this, [this](const bool alternative)
    {
        if (m_altSpeedEnabled == alternative)
            return;
        m_altSpeedEnabled = alternative;
        emit altSpeedEnabledChanged();
    });

    m_altSpeedEnabled = session->isAltGlobalSpeedLimitEnabled();
    refresh();
}

SessionFacade *SessionFacade::create(QQmlEngine *, QJSEngine *)
{
    return new SessionFacade;
}

SessionSnapshot SessionFacade::makeSnapshot(const BitTorrent::SessionStatus &st, const int torrentCount, const int activeCount)
{
    SessionSnapshot s;
    s.downloadRate = st.payloadDownloadRate;
    s.uploadRate = st.payloadUploadRate;
    // All-time totals (persisted across runs), not just this run's traffic
    s.totalDownloaded = st.allTimeDownload;
    s.totalUploaded = st.allTimeUpload;
    s.dhtNodes = static_cast<int>(st.dhtNodes);
    s.torrentCount = torrentCount;
    s.activeCount = activeCount;
    s.connected = st.hasIncomingConnections || (st.dhtNodes > 0);
    return s;
}

void SessionFacade::refresh()
{
    const auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    const QList<BitTorrent::Torrent *> torrents = session->torrents();
    int active = 0;
    for (const BitTorrent::Torrent *torrent : torrents)
    {
        if ((torrent->downloadPayloadRate() > 0) || (torrent->uploadPayloadRate() > 0))
            ++active;
    }

    m_snapshot = makeSnapshot(session->status(), static_cast<int>(torrents.size()), active);
    m_listenPort = session->port();
    emit statsChanged();
}

qint64 SessionFacade::downloadRate() const
{
    return m_snapshot.downloadRate;
}

qint64 SessionFacade::uploadRate() const
{
    return m_snapshot.uploadRate;
}

qint64 SessionFacade::totalDownloaded() const
{
    return m_snapshot.totalDownloaded;
}

qint64 SessionFacade::totalUploaded() const
{
    return m_snapshot.totalUploaded;
}

int SessionFacade::dhtNodes() const
{
    return m_snapshot.dhtNodes;
}

int SessionFacade::torrentCount() const
{
    return m_snapshot.torrentCount;
}

int SessionFacade::activeCount() const
{
    return m_snapshot.activeCount;
}

bool SessionFacade::connected() const
{
    return m_snapshot.connected;
}

int SessionFacade::listenPort() const
{
    return m_listenPort;
}

bool SessionFacade::altSpeedEnabled() const
{
    return m_altSpeedEnabled;
}

void SessionFacade::setAltSpeedEnabled(const bool enabled)
{
    // The change is reflected back through speedLimitModeChanged
    if (auto *session = BitTorrent::Session::instance())
        session->setAltGlobalSpeedLimitEnabled(enabled);
}
