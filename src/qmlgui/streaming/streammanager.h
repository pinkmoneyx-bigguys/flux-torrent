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

#include <memory>

#include <QHash>
#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include "streamplanner.h"

class QJSEngine;
class QQmlEngine;
class StreamServer;
class StreamSession;
class StreamStateStore;

// Streaming for QML: open(torrentId, fileIndex) gives the player a local URL for the file, served by
// StreamServer from a StreamSession. Owns the sessions, the server and streams.json; at creation it
// rolls back the torrents a crashed run left mid-stream, and it closes every stream when the app quits.
class StreamManager : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(StreamManager)
    QML_ELEMENT
    QML_SINGLETON

    // "fast", "smooth" (default), "economy"; kept in the profile and applied to open streams
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged FINAL)
    Q_PROPERTY(int openCount READ openCount NOTIFY streamsChanged FINAL)
    Q_PROPERTY(QString lastError READ lastError NOTIFY streamsChanged FINAL)

public:
    explicit StreamManager(QObject *parent = nullptr);
    ~StreamManager() override;

    static StreamManager *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    QString mode() const;
    void setMode(const QString &mode);
    int openCount() const;
    QString lastError() const;

    // The URL to play, or an empty URL (see lastError)
    Q_INVOKABLE QUrl open(const QString &torrentId, int fileIndex);
    Q_INVOKABLE void close(const QString &torrentId, int fileIndex);
    Q_INVOKABLE void closeAll();
    // The player's measured bitrate, for the smooth window
    Q_INVOKABLE void setBitrate(const QString &torrentId, int fileIndex, qint64 bytesPerSecond);
    // StreamSession::stats() of an open stream, or {}; `fromByte` is the playhead in the file
    Q_INVOKABLE QVariantMap stats(const QString &torrentId, int fileIndex, qint64 fromByte = -1) const;
    // Whether open() turned on a file marked "do not download" (the UI tells the user)
    Q_INVOKABLE bool enabledSkippedFile(const QString &torrentId, int fileIndex) const;

signals:
    void modeChanged();
    void streamsChanged();

private:
    static QString keyOf(const QString &torrentId, int fileIndex);
    StreamSession *session(const QString &key) const;
    void restoreLeftovers();

    std::unique_ptr<StreamStateStore> m_store;
    StreamServer *m_server = nullptr;
    QHash<QString, StreamSession *> m_sessions;
    StreamMode m_mode = StreamMode::Smooth;
    QString m_lastError;
};
