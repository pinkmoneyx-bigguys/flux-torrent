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

#include <QAbstractListModel>
#include <QDateTime>
#include <QList>
#include <QString>
#include <QTimer>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

// One video file of a torrent, with what its name says about it
struct MediaItem
{
    QString key;          // torrentId:fileIndex
    QString torrentId;
    int fileIndex = 0;
    QString fileName;
    QString torrentName;
    QString path;         // absolute path on disk
    QString title;        // cleaned up name
    int year = 0;
    int season = 0;
    int episode = 0;
    QString quality;      // "2160p", "1080p", "720p", "480p" or ""
    qint64 size = 0;
    qreal progress = 0;
    QDateTime added;
    bool torrentStopped = false;
};

// The media library: every video file (.mkv .mp4 .avi .webm .mov .m4v) of the session's torrents,
// filtered by kind and search words and sorted. Refreshed as the torrents change. FLUX_DEMO_MEDIA=<json>
// (and loadDemo in tests) fills it without a session.
class MediaLibraryModel : public QAbstractListModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(MediaLibraryModel)
    QML_ELEMENT
    QML_SINGLETON

    // "all", "movies", "series", "downloading"
    Q_PROPERTY(QString kind READ kind WRITE setKind NOTIFY filterChanged FINAL)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY filterChanged FINAL)
    // "added" (newest first), "title", "size"
    Q_PROPERTY(QString sortKey READ sortKey WRITE setSortKey NOTIFY filterChanged FINAL)
    Q_PROPERTY(int count READ rowCount NOTIFY countsChanged FINAL)
    // {all, movies, series, downloading}: items per kind before the search
    Q_PROPERTY(QVariantMap counts READ counts NOTIFY countsChanged FINAL)
    // The shown files by title, in the same order: a film (its files: the movie, another version) or a series
    // (its episodes), named as the torrent is (the local title first). [{key, posterKey, title, original, year,
    // series, quality, count, seasons, size, progress, downloading, main, items: [{key, season, episode,
    // quality, size, progress, complete, fileName}]}]; `main` is the file a click plays (a film's largest)
    Q_PROPERTY(QVariantList titles READ titles NOTIFY titlesChanged FINAL)

public:
    enum Role
    {
        KeyRole = Qt::UserRole + 1,
        TorrentIdRole,
        FileNameRole,
        TorrentNameRole,
        PathRole,
        TitleRole,
        YearRole,
        SeasonRole,
        EpisodeRole,
        QualityRole,
        SizeRole,
        ProgressRole,
        AddedRole,
        CompleteRole
    };

    explicit MediaLibraryModel(QObject *parent = nullptr);

    static MediaLibraryModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // What a release name says: {title, year, season, episode, quality}
    Q_INVOKABLE static QVariantMap parseName(const QString &fileName);
    static bool isVideoFile(const QString &fileName);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString kind() const;
    void setKind(const QString &kind);
    QString search() const;
    void setSearch(const QString &search);
    QString sortKey() const;
    void setSortKey(const QString &key);
    QVariantMap counts() const;
    QVariantList titles() const;
    // One entry of `titles` by its key, or {}
    Q_INVOKABLE QVariantMap title(const QString &key) const;

    // The item as a JS object, or an empty one
    Q_INVOKABLE QVariantMap get(const QString &key) const;
    // The key of a torrent's main video (its largest video file), or ""
    Q_INVOKABLE QString bestVideoOf(const QString &torrentId) const;
    // Opens a downloaded file in the default player; false while it is incomplete
    Q_INVOKABLE bool play(const QString &key);
    Q_INVOKABLE void showInFolder(const QString &key);

    // Tests and the demo file: [{torrentId, fileIndex, fileName, torrentName, path, size, progress, addedSecsAgo}]
    Q_INVOKABLE void loadDemo(const QVariantList &items);

signals:
    void filterChanged();
    void countsChanged();
    void titlesChanged();

private:
    void scheduleRefresh();
    void refresh();
    void applyFilter();
    // `titles` from the shown files
    void groupTitles();
    const MediaItem *find(const QString &key) const;

    QList<MediaItem> m_all;
    QList<MediaItem> m_visible;
    QVariantMap m_counts;
    QVariantList m_titles;
    QString m_kind = QStringLiteral("all");
    QString m_search;
    QString m_sortKey = QStringLiteral("added");
    QTimer m_refreshTimer;
    bool m_demo = false;
};
