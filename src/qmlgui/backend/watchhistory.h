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

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

// Where each video was left: position and duration per torrent file, for "Continue from ...". Kept in
// watch-history.json in the profile; writes are batched (at most every 5 s) and flushed on close.
class WatchHistory : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(WatchHistory)
    QML_ELEMENT
    QML_SINGLETON

    // Bumps on every change, for QML bindings
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    // Positions below this are not worth resuming, and so are files watched past RESUME_MAX
    static constexpr double RESUME_MIN_SECONDS = 30;
    static constexpr double RESUME_MAX = 0.95;
    static constexpr int MAX_ENTRIES = 500;

    // An empty path keeps everything in memory (tests)
    explicit WatchHistory(const QString &filePath, QObject *parent = nullptr);
    ~WatchHistory() override;

    static WatchHistory *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    int revision() const;

    Q_INVOKABLE static QString keyOf(const QString &torrentId, int fileIndex);
    Q_INVOKABLE void save(const QString &key, double position, double duration);
    Q_INVOKABLE double position(const QString &key) const;
    Q_INVOKABLE double duration(const QString &key) const;
    // Watched share, 0..1
    Q_INVOKABLE double progress(const QString &key) const;
    // Where "Continue from" starts, or 0 when there is nothing to continue
    Q_INVOKABLE double resumePosition(const QString &key) const;
    Q_INVOKABLE void clear(const QString &key);
    // Writes pending changes now
    Q_INVOKABLE void flush();

signals:
    void changed();

private:
    struct Entry
    {
        double position = 0;
        double duration = 0;
        QDateTime updated;
    };

    void load();
    void write();

    QString m_filePath;
    QHash<QString, Entry> m_entries;
    QTimer m_writeTimer;
    int m_revision = 0;
};
