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

#include "streamserver.h"

#include <algorithm>

#include <QFileInfo>
#include <QHostAddress>
#include <QPointer>
#include <QRandomGenerator>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>

#include "base/global.h"
#include "httprange.h"
#include "streamsource.h"

namespace
{
    constexpr qint64 CHUNK = 256 * 1024;
    constexpr qint64 SOCKET_BUDGET = 1024 * 1024;
    constexpr qsizetype MAX_HEADER = 16 * 1024;

    QByteArray contentType(const QString &fileName)
    {
        const QString ext = QFileInfo(fileName).suffix().toLower();
        if (ext == u"mkv")
            return "video/x-matroska";
        if ((ext == u"mp4") || (ext == u"m4v"))
            return "video/mp4";
        if (ext == u"webm")
            return "video/webm";
        if (ext == u"avi")
            return "video/x-msvideo";
        if (ext == u"mov")
            return "video/quicktime";
        return "application/octet-stream";
    }

    QString randomToken()
    {
        QString token;
        for (int i = 0; i < 4; ++i)
            token += QString::number(QRandomGenerator::system()->generate64(), 16).rightJustified(16, u'0');
        return token;
    }
}

// One client connection: parses the request, then sends the body as the source makes data available
class StreamConnection final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(StreamConnection)

public:
    StreamConnection(QTcpSocket *socket, StreamServer *server)
        : QObject(server)
        , m_socket {socket}
        , m_server {server}
    {
        m_socket->setParent(this);
        m_waitTimer.setSingleShot(true);
        connect(&m_waitTimer, &QTimer::timeout, this, &StreamConnection::finish);
        // data can also appear without a signal (pieces confirmed by a recheck): look again every second
        m_pollTimer.setInterval(1000);
        connect(&m_pollTimer, &QTimer::timeout, this, &StreamConnection::pump);
        connect(m_socket, &QTcpSocket::readyRead, this, &StreamConnection::onReadyRead);
        connect(m_socket, &QTcpSocket::bytesWritten, this, &StreamConnection::pump);
        connect(m_socket, &QTcpSocket::disconnected, this, &StreamConnection::finish);
    }

private:
    void onReadyRead()
    {
        if (m_headerDone)
            return;

        m_request += m_socket->readAll();
        const qsizetype end = m_request.indexOf("\r\n\r\n");
        if (end < 0)
        {
            if (m_request.size() > MAX_HEADER)
                respondError(431, "Request Header Fields Too Large");
            return;
        }
        m_headerDone = true;
        handleRequest(m_request.left(end));
    }

    void handleRequest(const QByteArray &head)
    {
        const QList<QByteArray> lines = head.split('\n');
        const QList<QByteArray> requestLine = lines.first().trimmed().split(' ');
        if (requestLine.size() < 2)
        {
            respondError(400, "Bad Request");
            return;
        }
        const QByteArray method = requestLine.at(0);
        const QString path = QUrl::fromPercentEncoding(requestLine.at(1));

        QByteArray rangeHeader;
        for (qsizetype i = 1; i < lines.size(); ++i)
        {
            const QByteArray line = lines.at(i).trimmed();
            if (line.toLower().startsWith("range:"))
                rangeHeader = line.mid(6).trimmed();
        }

        // /<token>/<key>
        const QString prefix = u'/' + m_server->m_token + u'/';
        if (!path.startsWith(prefix))
        {
            respondError(404, "Not Found");
            return;
        }
        m_source = m_server->m_provider ? m_server->m_provider(path.mid(prefix.size())) : nullptr;
        if (!m_source)
        {
            respondError(404, "Not Found");
            return;
        }
        if ((method != "GET") && (method != "HEAD"))
        {
            respondError(405, "Method Not Allowed");
            return;
        }

        const qint64 size = m_source->size();
        const HttpRange range = parseHttpRange(rangeHeader, size);
        if (!range.satisfiable)
        {
            QByteArray response = "HTTP/1.1 416 Range Not Satisfiable\r\n"
                "Content-Range: bytes */" + QByteArray::number(size) + "\r\n"
                "Content-Length: 0\r\nConnection: close\r\n\r\n";
            m_socket->write(response);
            closeWhenFlushed();
            return;
        }

        m_pos = range.start;
        m_end = range.end;
        QByteArray response = range.present ? "HTTP/1.1 206 Partial Content\r\n" : "HTTP/1.1 200 OK\r\n";
        response += "Content-Type: " + contentType(m_source->fileName()) + "\r\n";
        response += "Content-Length: " + QByteArray::number(std::max<qint64>(0, m_end - m_pos + 1)) + "\r\n";
        response += "Accept-Ranges: bytes\r\n";
        if (range.present)
            response += "Content-Range: bytes " + QByteArray::number(m_pos) + '-' + QByteArray::number(m_end) + '/' + QByteArray::number(size) + "\r\n";
        response += "Connection: close\r\n\r\n";
        m_socket->write(response);

        if ((method == "HEAD") || (m_end < m_pos))
        {
            closeWhenFlushed();
            return;
        }

        m_source->noteRead(m_pos);
        connect(m_source, &StreamSource::dataAvailable, this, &StreamConnection::pump);
        pump();
    }

    void pump()
    {
        if (!m_source || !m_headerDone || m_closing)
            return;

        while ((m_pos <= m_end) && (m_socket->bytesToWrite() < SOCKET_BUDGET))
        {
            const qint64 want = std::min<qint64>(CHUNK, m_end - m_pos + 1);
            const qint64 ready = m_source->available(m_pos, want);
            if (ready <= 0)
            {
                // not downloaded yet: wait for the source, but not forever
                if (!m_waitTimer.isActive())
                    m_waitTimer.start(m_server->m_waitTimeout);
                if (!m_pollTimer.isActive())
                    m_pollTimer.start();
                return;
            }
            m_waitTimer.stop();
            m_pollTimer.stop();

            const QByteArray data = m_source->read(m_pos, ready);
            if (data.isEmpty())
            {
                finish();
                return;
            }
            m_socket->write(data);
            m_pos += data.size();
            m_source->noteRead(m_pos);
        }

        if (m_pos > m_end)
            closeWhenFlushed();
    }

    void respondError(const int code, const QByteArray &reason)
    {
        m_socket->write("HTTP/1.1 " + QByteArray::number(code) + ' ' + reason
            + "\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        closeWhenFlushed();
    }

    void closeWhenFlushed()
    {
        m_closing = true;
        m_waitTimer.stop();
        m_pollTimer.stop();
        if (m_socket->bytesToWrite() == 0)
            m_socket->disconnectFromHost();
        else
            connect(m_socket, &QTcpSocket::bytesWritten, this, [this] { if (m_socket->bytesToWrite() == 0) m_socket->disconnectFromHost(); });
    }

    void finish()
    {
        if (m_finished)
            return;
        m_finished = true;
        m_waitTimer.stop();
        m_pollTimer.stop();
        m_socket->abort();
        --m_server->m_connections;
        emit m_server->connectionCountChanged();
        deleteLater();
    }

    QTcpSocket *m_socket = nullptr;
    StreamServer *m_server = nullptr;
    QPointer<StreamSource> m_source;
    QByteArray m_request;
    bool m_headerDone = false;
    bool m_closing = false;
    bool m_finished = false;
    qint64 m_pos = 0;
    qint64 m_end = -1;
    QTimer m_waitTimer;
    QTimer m_pollTimer;
};

StreamServer::StreamServer(SourceProvider provider, QObject *parent)
    : QObject(parent)
    , m_provider {std::move(provider)}
    , m_server {new QTcpServer(this)}
    , m_token {randomToken()}
{
    connect(m_server, &QTcpServer::newConnection, this, &StreamServer::onNewConnection);
}

StreamServer::~StreamServer() = default;

bool StreamServer::start()
{
    if (m_server->isListening())
        return true;
    return m_server->listen(QHostAddress::LocalHost, 0);
}

bool StreamServer::isListening() const
{
    return m_server->isListening();
}

quint16 StreamServer::port() const
{
    return m_server->serverPort();
}

QString StreamServer::token() const
{
    return m_token;
}

QUrl StreamServer::url(const QString &key) const
{
    return QUrl(u"http://127.0.0.1:%1/%2/%3"_s.arg(port()).arg(m_token, key));
}

int StreamServer::waitTimeout() const
{
    return m_waitTimeout;
}

void StreamServer::setWaitTimeout(const int ms)
{
    m_waitTimeout = ms;
}

int StreamServer::connectionCount() const
{
    return m_connections;
}

void StreamServer::onNewConnection()
{
    while (QTcpSocket *socket = m_server->nextPendingConnection())
    {
        new StreamConnection(socket, this);
        ++m_connections;
        emit connectionCountChanged();
    }
}

#include "streamserver.moc"
