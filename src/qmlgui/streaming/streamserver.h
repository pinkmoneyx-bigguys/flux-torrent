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

#include <QObject>
#include <QString>
#include <QUrl>

class QTcpServer;
class StreamSource;

// A minimal HTTP/1.1 server for the built-in player: http://127.0.0.1:<port>/<token>/<key>.
//   - listens on 127.0.0.1 only, on a random port; paths without the random token get 404;
//   - GET and HEAD, "Range: bytes=" (200, 206, 416), Content-Length, Accept-Ranges, Content-Type;
//   - bytes that are not downloaded yet are waited for (StreamSource::dataAvailable), up to the wait
//     timeout per chunk, instead of failing; data goes out in 256 KiB chunks while the socket holds
//     less than 1 MiB.
// Not Qt HttpServer: the response must stream and wait for pieces with its own timeouts.
class StreamServer final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(StreamServer)

public:
    // The source of a key ("<torrentId>/<fileIndex>"), or null for 404; owned by the caller
    using SourceProvider = std::function<StreamSource *(const QString &key)>;

    explicit StreamServer(SourceProvider provider, QObject *parent = nullptr);
    ~StreamServer() override;

    bool start();
    bool isListening() const;
    quint16 port() const;
    QString token() const;
    QUrl url(const QString &key) const;

    int waitTimeout() const;
    void setWaitTimeout(int ms);
    int connectionCount() const;

signals:
    void connectionCountChanged();

private:
    friend class StreamConnection;

    void onNewConnection();

    SourceProvider m_provider;
    QTcpServer *m_server = nullptr;
    QString m_token;
    int m_waitTimeout = 60000;
    int m_connections = 0;
};
