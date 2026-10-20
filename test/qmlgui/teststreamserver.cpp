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

#include <QElapsedTimer>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QObject>
#include <QRandomGenerator>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>

#include "base/global.h"
#include "qmlgui/streaming/filestreamsource.h"
#include "qmlgui/streaming/streamserver.h"

// StreamServer over a downloaded file: the bytes of every Range match the file, missing bytes are
// waited for, and the edges (HEAD, 404, 416, timeout) behave.
class TestStreamServer final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestStreamServer)

public:
    TestStreamServer() = default;

private:
    static constexpr qint64 SIZE = 3 * 1024 * 1024 + 12345;

    QTemporaryDir m_dir;
    QByteArray m_data;
    FileStreamSource *m_source = nullptr;
    StreamServer *m_server = nullptr;
    QNetworkAccessManager m_net;

    QNetworkReply *get(const QUrl &url, const QByteArray &range = {}, const QByteArray &verb = "GET")
    {
        QNetworkRequest request {url};
        request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
        if (!range.isEmpty())
            request.setRawHeader("Range", range);
        return m_net.sendCustomRequest(request, verb);
    }

    static bool waitFinished(QNetworkReply *reply, const int ms = 10000)
    {
        if (reply->isFinished())
            return true;
        QSignalSpy spy {reply, &QNetworkReply::finished};
        return spy.wait(ms);
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        m_data.resize(SIZE);
        auto *gen = QRandomGenerator::global();
        for (qsizetype i = 0; i < m_data.size(); ++i)
            m_data[i] = static_cast<char>(gen->bounded(256));
        QFile file {m_dir.filePath(u"movie.mkv"_s)};
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(m_data);
        file.close();

        m_source = new FileStreamSource(file.fileName(), this);
        m_server = new StreamServer([this](const QString &key) -> StreamSource *
        {
            return (key == u"abc/0") ? m_source : nullptr;
        }, this);
        QVERIFY(m_server->start());
        m_net.setProxy(QNetworkProxy::NoProxy);
    }

    void init()
    {
        m_source->setAvailableLimit(-1);
        m_server->setWaitTimeout(60000);
    }

    void rangesMatchFile_data()
    {
        QTest::addColumn<QByteArray>("range");
        QTest::addColumn<int>("status");
        QTest::addColumn<qint64>("start");
        QTest::addColumn<qint64>("end");

        QTest::newRow("whole") << QByteArray() << 200 << qint64(0) << (SIZE - 1);
        QTest::newRow("start") << QByteArray("bytes=0-1023") << 206 << qint64(0) << qint64(1023);
        QTest::newRow("middle across chunks") << QByteArray("bytes=262000-800000") << 206 << qint64(262000) << qint64(800000);
        QTest::newRow("open") << QByteArray("bytes=3000000-") << 206 << qint64(3000000) << (SIZE - 1);
        QTest::newRow("suffix") << QByteArray("bytes=-4096") << 206 << (SIZE - 4096) << (SIZE - 1);
        QTest::newRow("last byte") << QByteArray("bytes=-1") << 206 << (SIZE - 1) << (SIZE - 1);
    }

    void rangesMatchFile()
    {
        QFETCH(QByteArray, range);
        QFETCH(int, status);
        QFETCH(qint64, start);
        QFETCH(qint64, end);

        QNetworkReply *reply = get(m_server->url(u"abc/0"_s), range);
        QVERIFY(waitFinished(reply));
        QCOMPARE(reply->error(), QNetworkReply::NoError);
        QCOMPARE(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), status);
        QCOMPARE(reply->rawHeader("Accept-Ranges"), QByteArray("bytes"));
        QCOMPARE(reply->rawHeader("Content-Type"), QByteArray("video/x-matroska"));
        if (status == 206)
        {
            QCOMPARE(reply->rawHeader("Content-Range"),
                "bytes " + QByteArray::number(start) + '-' + QByteArray::number(end) + '/' + QByteArray::number(SIZE));
        }
        const QByteArray body = reply->readAll();
        QCOMPARE(body.size(), end - start + 1);
        QVERIFY(body == m_data.mid(start, end - start + 1));
        reply->deleteLater();
    }

    void headHasNoBody()
    {
        QNetworkReply *reply = get(m_server->url(u"abc/0"_s), "bytes=10-19", "HEAD");
        QVERIFY(waitFinished(reply));
        QCOMPARE(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 206);
        QCOMPARE(reply->header(QNetworkRequest::ContentLengthHeader).toLongLong(), 10);
        QVERIFY(reply->readAll().isEmpty());
        reply->deleteLater();
    }

    void badTokenIs404()
    {
        QUrl url = m_server->url(u"abc/0"_s);
        url.setPath(u"/wrong-token/abc/0"_s);
        QNetworkReply *reply = get(url);
        QVERIFY(waitFinished(reply));
        QCOMPARE(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 404);
        reply->deleteLater();

        QNetworkReply *unknown = get(m_server->url(u"zzz/9"_s));
        QVERIFY(waitFinished(unknown));
        QCOMPARE(unknown->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 404);
        unknown->deleteLater();
    }

    void unsatisfiableIs416()
    {
        QNetworkReply *reply = get(m_server->url(u"abc/0"_s), "bytes=" + QByteArray::number(SIZE) + '-');
        QVERIFY(waitFinished(reply));
        QCOMPARE(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(), 416);
        QCOMPARE(reply->rawHeader("Content-Range"), "bytes */" + QByteArray::number(SIZE));
        reply->deleteLater();
    }

    void listensOnLoopbackOnly()
    {
        QCOMPARE(m_server->url(u"x"_s).host(), u"127.0.0.1"_s);
        QVERIFY(m_server->token().size() >= 32);
    }

    void waitsForMissingData()
    {
        // only the first MiB is "downloaded"; the rest arrives 300 ms later
        m_source->setAvailableLimit(1024 * 1024);
        QElapsedTimer timer;
        timer.start();
        QNetworkReply *reply = get(m_server->url(u"abc/0"_s), "bytes=2000000-2100000");
        QTimer::singleShot(300, this, [this] { m_source->setAvailableLimit(-1); });
        QVERIFY(waitFinished(reply));
        QVERIFY2(timer.elapsed() >= 280, "the answer waited for the data");
        QCOMPARE(reply->error(), QNetworkReply::NoError);
        QVERIFY(reply->readAll() == m_data.mid(2000000, 100001));
        QCOMPARE(m_source->lastReadOffset(), qint64(2100001));
        reply->deleteLater();
    }

    void timeoutClosesConnection()
    {
        m_server->setWaitTimeout(300);
        m_source->setAvailableLimit(0);
        QNetworkReply *reply = get(m_server->url(u"abc/0"_s), "bytes=0-99");
        QVERIFY(waitFinished(reply, 5000));
        QVERIFY2(reply->readAll().size() < 100, "no full body without the data");
        reply->deleteLater();
        QTRY_COMPARE(m_server->connectionCount(), 0);
    }
};

QTEST_GUILESS_MAIN(TestStreamServer)
#include "teststreamserver.moc"
