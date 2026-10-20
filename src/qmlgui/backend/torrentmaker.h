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
#include <QPointer>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

namespace BitTorrent
{
    class TorrentCreator;
}

// Creates .torrent files for QML: one job at a time on the global thread pool (BitTorrent::TorrentCreator),
// with progress, cancel, and optionally seeding the new torrent from where its files are.
class TorrentMaker : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TorrentMaker)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    // 0..100 while busy
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged FINAL)

public:
    explicit TorrentMaker(QObject *parent = nullptr);
    ~TorrentMaker() override;

    bool busy() const;
    int progress() const;

    // {source (file or folder: path or file:// URL), output (.torrent path; empty: next to the source),
    //  trackers (one per line, a blank line starts a new tier), webSeeds (one per line), comment,
    //  isPrivate, pieceSize (bytes, 0 auto), format ("hybrid", "v1", "v2"), startSeeding}
    // Returns an error to show at once, or "" when the job started (then created() or failed() follows).
    Q_INVOKABLE QString create(const QVariantMap &params);
    Q_INVOKABLE void cancel();
    // Where the .torrent goes by default: beside the source, named after it
    Q_INVOKABLE QString defaultOutput(const QString &source) const;
    // Local path of a file:// URL (or the text itself)
    Q_INVOKABLE QString toLocalPath(const QString &urlOrPath) const;

signals:
    void busyChanged();
    void progressChanged();
    void created(const QString &torrentPath, bool seeding);
    void failed(const QString &message);

private:
    void setProgress(int progress);

    QPointer<BitTorrent::TorrentCreator> m_creator;
    int m_progress = 0;
    bool m_startSeeding = false;
};
