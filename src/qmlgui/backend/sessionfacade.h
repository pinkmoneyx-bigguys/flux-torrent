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

#include <QObject>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

namespace BitTorrent
{
    struct SessionStatus;
}

// Plain values derived from one session stats update; the single place where the facade's numbers are computed.
struct SessionSnapshot
{
    qint64 downloadRate = 0;
    qint64 uploadRate = 0;
    qint64 totalDownloaded = 0;
    qint64 totalUploaded = 0;
    int dhtNodes = 0;
    int torrentCount = 0;
    int activeCount = 0;
    bool connected = false;
};

// Live session statistics and the alternative speed limits switch, exposed to QML.
class SessionFacade : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(SessionFacade)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(qint64 downloadRate READ downloadRate NOTIFY statsChanged)
    Q_PROPERTY(qint64 uploadRate READ uploadRate NOTIFY statsChanged)
    Q_PROPERTY(qint64 totalDownloaded READ totalDownloaded NOTIFY statsChanged)
    Q_PROPERTY(qint64 totalUploaded READ totalUploaded NOTIFY statsChanged)
    Q_PROPERTY(int dhtNodes READ dhtNodes NOTIFY statsChanged)
    Q_PROPERTY(int torrentCount READ torrentCount NOTIFY statsChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY statsChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY statsChanged)
    Q_PROPERTY(int listenPort READ listenPort NOTIFY statsChanged)
    Q_PROPERTY(bool altSpeedEnabled READ altSpeedEnabled WRITE setAltSpeedEnabled NOTIFY altSpeedEnabledChanged)

public:
    explicit SessionFacade(QObject *parent = nullptr);

    // Requires an existing BitTorrent::Session (QML is loaded after the session is restored).
    static SessionFacade *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // Pure mapping from core status to the values shown in the UI.
    static SessionSnapshot makeSnapshot(const BitTorrent::SessionStatus &st, int torrentCount, int activeCount);

    qint64 downloadRate() const;
    qint64 uploadRate() const;
    qint64 totalDownloaded() const;
    qint64 totalUploaded() const;
    int dhtNodes() const;
    int torrentCount() const;
    int activeCount() const;
    bool connected() const;
    int listenPort() const;

    bool altSpeedEnabled() const;
    void setAltSpeedEnabled(bool enabled);

signals:
    void statsChanged();
    void altSpeedEnabledChanged();

private:
    void refresh();

    SessionSnapshot m_snapshot;
    int m_listenPort = 0;
    bool m_altSpeedEnabled = false;
};
