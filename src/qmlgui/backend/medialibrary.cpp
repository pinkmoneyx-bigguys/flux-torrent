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

#include "medialibrary.h"

#include <QCollator>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <QUrl>

#include "base/bittorrent/infohash.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/global.h"
#include "base/path.h"

namespace
{
    const QStringList VIDEO_EXTENSIONS {u"mkv"_s, u"mp4"_s, u"avi"_s, u"webm"_s, u"mov"_s, u"m4v"_s};

    bool isSeries(const MediaItem &item)
    {
        return (item.season > 0) || (item.episode > 0);
    }

    bool matchesKind(const MediaItem &item, const QString &kind)
    {
        if (kind == u"movies")
            return !isSeries(item);
        if (kind == u"series")
            return isSeries(item);
        if (kind == u"downloading")
            return item.progress < 1;
        return true;
    }

    void fillParsed(MediaItem &item)
    {
        const QVariantMap parsed = MediaLibraryModel::parseName(item.fileName);
        item.title = parsed.value(u"title"_s).toString();
        item.year = parsed.value(u"year"_s).toInt();
        item.season = parsed.value(u"season"_s).toInt();
        item.episode = parsed.value(u"episode"_s).toInt();
        item.quality = parsed.value(u"quality"_s).toString();
    }
}

MediaLibraryModel::MediaLibraryModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(1500);
    connect(&m_refreshTimer, &QTimer::timeout, this, &MediaLibraryModel::refresh);

    // Development aid for window captures
    if (const QString demo = qEnvironmentVariable("FLUX_DEMO_MEDIA"); !demo.isEmpty())
    {
        QFile file {demo};
        if (file.open(QIODevice::ReadOnly))
        {
            loadDemo(QJsonDocument::fromJson(file.readAll()).array().toVariantList());
            return;
        }
    }

    auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    // progress changes every second: refresh at most every 1.5 s; membership changes refresh soon
    connect(session, &BitTorrent::Session::torrentsUpdated, this, &MediaLibraryModel::scheduleRefresh);
    connect(session, &BitTorrent::Session::torrentAdded, this, [this] { QTimer::singleShot(0, this, &MediaLibraryModel::refresh); });
    connect(session, &BitTorrent::Session::torrentMetadataReceived, this, [this] { QTimer::singleShot(0, this, &MediaLibraryModel::refresh); });
    connect(session, &BitTorrent::Session::torrentAboutToBeRemoved, this, [this] { QTimer::singleShot(0, this, &MediaLibraryModel::refresh); });
    connect(session, &BitTorrent::Session::torrentsLoaded, this, &MediaLibraryModel::refresh);
    refresh();
}

MediaLibraryModel *MediaLibraryModel::create(QQmlEngine *, QJSEngine *)
{
    return new MediaLibraryModel;
}

bool MediaLibraryModel::isVideoFile(const QString &fileName)
{
    const qsizetype dot = fileName.lastIndexOf(u'.');
    return (dot > 0) && VIDEO_EXTENSIONS.contains(fileName.mid(dot + 1).toLower());
}

QVariantMap MediaLibraryModel::parseName(const QString &fileName)
{
    QString name = QFileInfo(fileName).fileName();
    if (isVideoFile(name))
        name = name.left(name.lastIndexOf(u'.'));
    // leading [Group] tags
    static const QRegularExpression leadingTags {u"^(\\s*\\[[^\\]]*\\])+\\s*"_s};
    name.remove(leadingTags);
    name.replace(u'_', u' ');
    // dots between words are separators; keep the dot of "5.1" and similar
    static const QRegularExpression wordDots {u"\\.(?!\\d)|(?<!\\d)\\."_s};
    name.replace(wordDots, u" "_s);

    qsizetype cut = name.size();
    QVariantMap result;

    static const QRegularExpression episodeRe {u"\\bS(\\d{1,2})\\s?E(\\d{1,3})\\b|\\b(\\d{1,2})x(\\d{2,3})\\b"_s,
        QRegularExpression::CaseInsensitiveOption};
    if (const QRegularExpressionMatch m = episodeRe.match(name); m.hasMatch())
    {
        const bool sxe = !m.captured(1).isEmpty();
        result.insert(u"season"_s, (sxe ? m.captured(1) : m.captured(3)).toInt());
        result.insert(u"episode"_s, (sxe ? m.captured(2) : m.captured(4)).toInt());
        cut = std::min(cut, m.capturedStart());
    }

    static const QRegularExpression yearRe {u"[\\(\\[]?\\b(19\\d\\d|20\\d\\d)\\b[\\)\\]]?"_s};
    // the first year that is not the very start of the name ("2001 A Space Odyssey" keeps its title)
    QRegularExpressionMatchIterator years = yearRe.globalMatch(name);
    while (years.hasNext())
    {
        const QRegularExpressionMatch m = years.next();
        if (m.capturedStart() == 0)
            continue;
        result.insert(u"year"_s, m.captured(1).toInt());
        cut = std::min(cut, m.capturedStart());
        break;
    }

    static const QRegularExpression qualityRe {u"\\b(2160p|4K|UHD|1080p|1080i|720p|576p|480p)\\b"_s, QRegularExpression::CaseInsensitiveOption};
    if (const QRegularExpressionMatch m = qualityRe.match(name); m.hasMatch())
    {
        const QString q = m.captured(1).toLower();
        result.insert(u"quality"_s, ((q == u"4k") || (q == u"uhd")) ? u"2160p"_s : (q == u"1080i") ? u"1080p"_s : q);
        cut = std::min(cut, m.capturedStart());
    }

    static const QRegularExpression tagsRe {
        u"\\b(WEB[- ]?DL|WEB[- ]?Rip|WEB|BluRay|BDRip|BRRip|HDRip|DVDRip|HDTV|HDR10?|DV|REMUX|x26[45]|H ?26[45]|HEVC|AV1|AAC|DDP?5 1|REPACK|PROPER|EXTENDED|UNRATED|MULTI)\\b"_s,
        QRegularExpression::CaseInsensitiveOption};
    if (const QRegularExpressionMatch m = tagsRe.match(name); m.hasMatch() && (m.capturedStart() > 0))
        cut = std::min(cut, m.capturedStart());

    QString title = name.left(cut);
    static const QRegularExpression trailing {u"[\\s\\-\\(\\[\\.]+$"_s};
    title.remove(trailing);
    title = title.simplified();
    result.insert(u"title"_s, title.isEmpty() ? name.simplified() : title);
    if (!result.contains(u"quality"_s))
        result.insert(u"quality"_s, QString());
    return result;
}

int MediaLibraryModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_visible.size());
}

QVariant MediaLibraryModel::data(const QModelIndex &index, const int role) const
{
    if (!index.isValid() || (index.row() >= m_visible.size()))
        return {};

    const MediaItem &m = m_visible.at(index.row());
    switch (role)
    {
    case Qt::DisplayRole:
    case TitleRole: return m.title;
    case KeyRole: return m.key;
    case TorrentIdRole: return m.torrentId;
    case FileNameRole: return m.fileName;
    case TorrentNameRole: return m.torrentName;
    case PathRole: return m.path;
    case YearRole: return m.year;
    case SeasonRole: return m.season;
    case EpisodeRole: return m.episode;
    case QualityRole: return m.quality;
    case SizeRole: return m.size;
    case ProgressRole: return m.progress;
    case AddedRole: return m.added;
    case CompleteRole: return m.progress >= 1;
    default: return {};
    }
}

QHash<int, QByteArray> MediaLibraryModel::roleNames() const
{
    return {
        {KeyRole, "key"},
        {TorrentIdRole, "torrentId"},
        {FileNameRole, "fileName"},
        {TorrentNameRole, "torrentName"},
        {PathRole, "path"},
        {TitleRole, "title"},
        {YearRole, "year"},
        {SeasonRole, "season"},
        {EpisodeRole, "episode"},
        {QualityRole, "quality"},
        {SizeRole, "size"},
        {ProgressRole, "progress"},
        {AddedRole, "added"},
        {CompleteRole, "complete"}
    };
}

QString MediaLibraryModel::kind() const
{
    return m_kind;
}

void MediaLibraryModel::setKind(const QString &kind)
{
    if (kind == m_kind)
        return;
    m_kind = kind;
    emit filterChanged();
    applyFilter();
}

QString MediaLibraryModel::search() const
{
    return m_search;
}

void MediaLibraryModel::setSearch(const QString &search)
{
    if (search == m_search)
        return;
    m_search = search;
    emit filterChanged();
    applyFilter();
}

QString MediaLibraryModel::sortKey() const
{
    return m_sortKey;
}

void MediaLibraryModel::setSortKey(const QString &key)
{
    if (key == m_sortKey)
        return;
    m_sortKey = key;
    emit filterChanged();
    applyFilter();
}

QVariantMap MediaLibraryModel::counts() const
{
    return m_counts;
}

const MediaItem *MediaLibraryModel::find(const QString &key) const
{
    for (const MediaItem &m : m_all)
    {
        if (m.key == key)
            return &m;
    }
    return nullptr;
}

QVariantMap MediaLibraryModel::get(const QString &key) const
{
    const MediaItem *m = find(key);
    if (!m)
        return {};
    return {
        {u"key"_s, m->key}, {u"torrentId"_s, m->torrentId}, {u"fileIndex"_s, m->fileIndex}, {u"fileName"_s, m->fileName},
        {u"torrentName"_s, m->torrentName}, {u"path"_s, m->path}, {u"title"_s, m->title}, {u"year"_s, m->year},
        {u"season"_s, m->season}, {u"episode"_s, m->episode}, {u"quality"_s, m->quality}, {u"size"_s, m->size},
        {u"progress"_s, m->progress}, {u"added"_s, m->added}, {u"complete"_s, m->progress >= 1}
    };
}

QString MediaLibraryModel::bestVideoOf(const QString &torrentId) const
{
    const MediaItem *best = nullptr;
    for (const MediaItem &m : m_all)
    {
        if ((m.torrentId == torrentId) && (!best || (m.size > best->size)))
            best = &m;
    }
    return best ? best->key : QString();
}

bool MediaLibraryModel::play(const QString &key)
{
    const MediaItem *m = find(key);
    if (!m || (m->progress < 1))
        return false;
    if (m_demo)
        return true;
    return QDesktopServices::openUrl(QUrl::fromLocalFile(m->path));
}

void MediaLibraryModel::showInFolder(const QString &key)
{
    const MediaItem *m = find(key);
    if (!m || m_demo)
        return;
    if (QFileInfo::exists(m->path))
        QProcess::startDetached(u"explorer.exe"_s, {u"/select,"_s + QDir::toNativeSeparators(m->path)});
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(m->path).absolutePath()));
}

void MediaLibraryModel::scheduleRefresh()
{
    if (!m_refreshTimer.isActive())
        m_refreshTimer.start();
}

void MediaLibraryModel::refresh()
{
    if (m_demo)
        return;
    const auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    QList<MediaItem> items;
    for (const BitTorrent::Torrent *torrent : session->torrents())
    {
        if (!torrent->hasMetadata())
            continue;

        const int count = torrent->filesCount();
        QList<qreal> progress;
        for (int i = 0; i < count; ++i)
        {
            const Path filePath = torrent->filePath(i);
            const QString fileName = filePath.filename();
            if (!isVideoFile(fileName))
                continue;
            if (progress.isEmpty())
                progress = torrent->filesProgress();

            MediaItem item;
            item.torrentId = torrent->id().toString();
            item.fileIndex = i;
            item.key = item.torrentId + u':' + QString::number(i);
            item.fileName = fileName;
            item.torrentName = torrent->name();
            item.path = torrent->actualFilePath(i).isAbsolute()
                ? torrent->actualFilePath(i).toString()
                : (torrent->actualStorageLocation() / torrent->actualFilePath(i)).toString();
            item.size = torrent->fileSize(i);
            item.progress = (i < progress.size()) ? progress.at(i) : 0;
            item.added = torrent->addedTime();
            item.torrentStopped = torrent->isStopped();
            fillParsed(item);
            items.append(item);
        }
    }
    m_all = items;
    applyFilter();
}

void MediaLibraryModel::applyFilter()
{
    QVariantMap counts;
    for (const QString &k : {u"all"_s, u"movies"_s, u"series"_s, u"downloading"_s})
    {
        int n = 0;
        for (const MediaItem &m : std::as_const(m_all))
            n += matchesKind(m, k) ? 1 : 0;
        counts.insert(k, n);
    }

    const QStringList words = m_search.split(u' ', Qt::SkipEmptyParts);
    QList<MediaItem> visible;
    for (const MediaItem &m : std::as_const(m_all))
    {
        if (!matchesKind(m, m_kind))
            continue;
        bool ok = true;
        for (const QString &w : words)
        {
            if (!m.title.contains(w, Qt::CaseInsensitive) && !m.fileName.contains(w, Qt::CaseInsensitive))
            {
                ok = false;
                break;
            }
        }
        if (ok)
            visible.append(m);
    }

    static const QCollator collator = []
    {
        QCollator c;
        c.setNumericMode(true);
        c.setCaseSensitivity(Qt::CaseInsensitive);
        return c;
    }();
    std::stable_sort(visible.begin(), visible.end(), [this](const MediaItem &a, const MediaItem &b)
    {
        if (m_sortKey == u"title")
        {
            const int c = collator.compare(a.title, b.title);
            if (c != 0)
                return c < 0;
            return (a.season != b.season) ? (a.season < b.season) : (a.episode < b.episode);
        }
        if (m_sortKey == u"size")
            return a.size > b.size;
        if (a.added != b.added)
            return a.added > b.added;
        return a.fileName < b.fileName;
    });

    beginResetModel();
    m_visible = visible;
    endResetModel();
    if (counts != m_counts)
        m_counts = counts;
    emit countsChanged();
}

void MediaLibraryModel::loadDemo(const QVariantList &list)
{
    m_demo = true;
    QList<MediaItem> items;
    for (const QVariant &v : list)
    {
        const QVariantMap map = v.toMap();
        MediaItem item;
        item.torrentId = map.value(u"torrentId"_s).toString();
        item.fileIndex = map.value(u"fileIndex"_s).toInt();
        item.key = item.torrentId + u':' + QString::number(item.fileIndex);
        item.fileName = map.value(u"fileName"_s).toString();
        item.torrentName = map.value(u"torrentName"_s, item.fileName).toString();
        item.path = map.value(u"path"_s).toString();
        item.size = map.value(u"size"_s).toLongLong();
        item.progress = map.value(u"progress"_s, 1).toReal();
        item.added = QDateTime::currentDateTime().addSecs(-map.value(u"addedSecsAgo"_s, 3600).toLongLong());
        fillParsed(item);
        items.append(item);
    }
    m_all = items;
    applyFilter();
}
