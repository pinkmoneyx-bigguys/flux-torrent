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

#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include "base/bittorrent/torrentdescriptor.h"

namespace BitTorrent
{
    class TorrentInfo;
}

// One torrent about to be added, for the Add torrent dialog: loads a .torrent file or a magnet link
// (fetching the metadata of a magnet), exposes its files as a tree with checkboxes, and the options of
// the addition; accept() adds it to the session. loadDemo() fills it without a session (tests, captures).
class AddTorrentDraft : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(AddTorrentDraft)
    QML_ELEMENT

    // A file URL / path to a .torrent, or a magnet link / info hash
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    // "empty", "metadata" (fetching a magnet's file list), "ready", "error"
    Q_PROPERTY(QString status READ status NOTIFY changed FINAL)
    Q_PROPERTY(QString error READ error NOTIFY changed FINAL)
    Q_PROPERTY(QString name READ name NOTIFY changed FINAL)
    Q_PROPERTY(QString comment READ comment NOTIFY changed FINAL)
    Q_PROPERTY(QString hash READ hash NOTIFY changed FINAL)
    Q_PROPERTY(bool hasMetadata READ hasMetadata NOTIFY changed FINAL)
    Q_PROPERTY(bool alreadyAdded READ alreadyAdded NOTIFY changed FINAL)
    Q_PROPERTY(qint64 totalSize READ totalSize NOTIFY changed FINAL)
    Q_PROPERTY(qint64 wantedSize READ wantedSize NOTIFY filesChanged FINAL)
    Q_PROPERTY(int fileCount READ fileCount NOTIFY changed FINAL)
    Q_PROPERTY(int wantedCount READ wantedCount NOTIFY filesChanged FINAL)
    // Visible rows of the file tree: [{row, name, path, depth, folder, size, state (0 off, 1 some, 2 on), expanded}]
    Q_PROPERTY(QVariantList files READ files NOTIFY filesChanged FINAL)

    Q_PROPERTY(QString savePath READ savePath WRITE setSavePath NOTIFY optionsChanged FINAL)
    Q_PROPERTY(qint64 freeSpace READ freeSpace NOTIFY optionsChanged FINAL)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY optionsChanged FINAL)
    Q_PROPERTY(QStringList categories READ categories NOTIFY changed FINAL)
    Q_PROPERTY(bool startNow MEMBER m_startNow NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool sequential MEMBER m_sequential NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool firstLastPieces MEMBER m_firstLast NOTIFY optionsChanged FINAL)
    Q_PROPERTY(bool skipChecking MEMBER m_skipChecking NOTIFY optionsChanged FINAL)
    // "original", "subfolder", "noSubfolder"
    Q_PROPERTY(QString contentLayout MEMBER m_contentLayout NOTIFY optionsChanged FINAL)

public:
    explicit AddTorrentDraft(QObject *parent = nullptr);
    ~AddTorrentDraft() override;

    QString source() const;
    void setSource(const QString &source);
    QString status() const;
    QString error() const;
    QString name() const;
    QString comment() const;
    QString hash() const;
    bool hasMetadata() const;
    bool alreadyAdded() const;
    qint64 totalSize() const;
    qint64 wantedSize() const;
    int fileCount() const;
    int wantedCount() const;
    QVariantList files() const;
    QString savePath() const;
    void setSavePath(const QString &path);
    qint64 freeSpace() const;
    QString category() const;
    void setCategory(const QString &category);
    QStringList categories() const;

    // Check/uncheck a row of `files` (a folder applies to everything under it)
    Q_INVOKABLE void toggle(int row);
    Q_INVOKABLE void setAllWanted(bool wanted);
    Q_INVOKABLE void toggleExpanded(int row);
    // Adds the torrent; returns "" on success or the error text
    Q_INVOKABLE QString accept();
    // Drops the draft (and stops fetching a magnet's metadata)
    Q_INVOKABLE void cancel();

    // {name, comment, hash, magnet (bool), files: [{path, size}], categories: [...], savePath}
    Q_INVOKABLE void loadDemo(const QVariantMap &state);

signals:
    void sourceChanged();
    void changed();
    void filesChanged();
    void optionsChanged();
    // accept() added the torrent
    void added(const QString &name);

private:
    struct FileEntry
    {
        QString path;   // with '/' separators
        qint64 size = 0;
        bool wanted = true;
    };
    struct Row
    {
        QString path;   // folder path, or the file path
        QString name;
        int depth = 0;
        bool folder = false;
        int file = -1;  // file index
    };

    void reset();
    void setError(const QString &error);
    void setFilesFromInfo(const BitTorrent::TorrentInfo &info);
    void rebuildRows();
    void onMetadataDownloaded(const BitTorrent::TorrentInfo &info);
    QList<int> filesUnder(const QString &folder) const;

    QString m_source;
    QString m_status = QStringLiteral("empty");
    QString m_error;
    QString m_name;
    QString m_comment;
    QString m_hash;
    bool m_magnet = false;
    bool m_hasMetadata = false;
    bool m_alreadyAdded = false;
    bool m_fetching = false;
    bool m_demo = false;
    BitTorrent::TorrentDescriptor m_descriptor;
    QList<FileEntry> m_files;
    QSet<QString> m_collapsed;
    QList<Row> m_rows;     // visible rows
    QVariantList m_rowMaps;
    QString m_savePath;
    QString m_category;
    QStringList m_categories;
    bool m_startNow = true;
    bool m_sequential = false;
    bool m_firstLast = false;
    bool m_skipChecking = false;
    QString m_contentLayout = QStringLiteral("original");
};
