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

#include "addtorrentdraft.h"

#include <numeric>

#include <QCollator>
#include <QDir>
#include <QFileInfo>
#include <QStorageInfo>
#include <QUrl>

#include "base/bittorrent/addtorrentparams.h"
#include "base/bittorrent/downloadpriority.h"
#include "base/bittorrent/infohash.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrentcontentlayout.h"
#include "base/bittorrent/torrentinfo.h"
#include "base/global.h"
#include "base/path.h"

using BitTorrent::Session;

namespace
{
    QString parentOf(const QString &path)
    {
        const qsizetype slash = path.lastIndexOf(u'/');
        return (slash > 0) ? path.left(slash) : QString();
    }
}

AddTorrentDraft::AddTorrentDraft(QObject *parent)
    : QObject(parent)
{
    if (const Session *session = Session::instance())
    {
        m_savePath = session->savePath().toString();
        m_startNow = !session->isAddTorrentStopped();
        m_categories = session->categories();
        m_categories.sort(Qt::CaseInsensitive);
        connect(session, &Session::metadataDownloaded, this, &AddTorrentDraft::onMetadataDownloaded);
    }
}

AddTorrentDraft::~AddTorrentDraft()
{
    cancel();
}

QString AddTorrentDraft::source() const { return m_source; }
QString AddTorrentDraft::status() const { return m_status; }
QString AddTorrentDraft::error() const { return m_error; }
QString AddTorrentDraft::name() const { return m_name; }
QString AddTorrentDraft::comment() const { return m_comment; }
QString AddTorrentDraft::hash() const { return m_hash; }
bool AddTorrentDraft::hasMetadata() const { return m_hasMetadata; }
bool AddTorrentDraft::alreadyAdded() const { return m_alreadyAdded; }
int AddTorrentDraft::fileCount() const { return static_cast<int>(m_files.size()); }
QVariantList AddTorrentDraft::files() const { return m_rowMaps; }
QString AddTorrentDraft::savePath() const { return m_savePath; }
QString AddTorrentDraft::category() const { return m_category; }
QStringList AddTorrentDraft::categories() const { return m_categories; }

qint64 AddTorrentDraft::totalSize() const
{
    qint64 total = 0;
    for (const FileEntry &f : m_files)
        total += f.size;
    return total;
}

qint64 AddTorrentDraft::wantedSize() const
{
    qint64 total = 0;
    for (const FileEntry &f : m_files)
        total += f.wanted ? f.size : 0;
    return total;
}

int AddTorrentDraft::wantedCount() const
{
    int n = 0;
    for (const FileEntry &f : m_files)
        n += f.wanted ? 1 : 0;
    return n;
}

void AddTorrentDraft::setSavePath(const QString &path)
{
    QString value = path.trimmed();
    if (value.startsWith(u"file:"))
        value = QUrl(value).toLocalFile();
    if (value == m_savePath)
        return;
    m_savePath = value;
    emit optionsChanged();
}

qint64 AddTorrentDraft::freeSpace() const
{
    // the closest existing folder of the save path decides the drive
    QString dir = m_savePath;
    while (!dir.isEmpty() && !QFileInfo::exists(dir))
    {
        const QString up = QFileInfo(dir).absolutePath();
        if (up == dir)
            break;
        dir = up;
    }
    const QStorageInfo storage {dir.isEmpty() ? QDir::homePath() : dir};
    return storage.isValid() ? storage.bytesAvailable() : -1;
}

void AddTorrentDraft::setCategory(const QString &category)
{
    const QString value = category.trimmed();
    if (value == m_category)
        return;
    m_category = value;
    // a known category with its own folder moves the save path there
    if (const Session *session = Session::instance(); session && !value.isEmpty() && session->categories().contains(value))
    {
        const Path categoryPath = session->categorySavePath(value);
        if (!categoryPath.isEmpty())
            m_savePath = categoryPath.toString();
    }
    emit optionsChanged();
}

void AddTorrentDraft::reset()
{
    cancel();
    m_status = u"empty"_s;
    m_error.clear();
    m_name.clear();
    m_comment.clear();
    m_hash.clear();
    m_magnet = false;
    m_hasMetadata = false;
    m_alreadyAdded = false;
    m_descriptor = {};
    m_files.clear();
    m_collapsed.clear();
}

void AddTorrentDraft::setError(const QString &error)
{
    m_status = u"error"_s;
    m_error = error;
}

void AddTorrentDraft::setSource(const QString &source)
{
    if (source == m_source)
        return;

    reset();
    m_source = source;
    emit sourceChanged();

    const QString text = source.trimmed();
    if (!text.isEmpty())
    {
        const bool isFile = text.startsWith(u"file:", Qt::CaseInsensitive) || text.endsWith(u".torrent", Qt::CaseInsensitive);
        const auto descriptor = isFile
            ? BitTorrent::TorrentDescriptor::loadFromFile(Path(text.startsWith(u"file:", Qt::CaseInsensitive) ? QUrl(text).toLocalFile() : text))
            : BitTorrent::TorrentDescriptor::parse(text);

        if (!descriptor)
        {
            setError(descriptor.error());
        }
        else
        {
            m_descriptor = descriptor.value();
            m_magnet = !isFile;
            m_name = m_descriptor.name();
            m_comment = m_descriptor.comment();
            const BitTorrent::InfoHash infoHash = m_descriptor.infoHash();
            m_hash = infoHash.v1().isValid() ? infoHash.v1().toString() : infoHash.v2().toString();

            Session *session = Session::instance();
            m_alreadyAdded = session && session->isKnownTorrent(infoHash);

            if (const auto &info = m_descriptor.info(); info && info->isValid())
            {
                setFilesFromInfo(*info);
                m_status = u"ready"_s;
            }
            else if (session && !m_alreadyAdded && session->downloadMetadata(m_descriptor))
            {
                m_fetching = true;
                m_status = u"metadata"_s;
            }
            else
            {
                m_status = u"ready"_s; // a magnet added without choosing files
            }
            if (m_name.isEmpty())
                m_name = m_hash;
        }
    }

    rebuildRows();
    emit changed();
    emit optionsChanged();
}

void AddTorrentDraft::onMetadataDownloaded(const BitTorrent::TorrentInfo &info)
{
    if (!m_fetching || !info.matchesInfoHash(m_descriptor.infoHash()))
        return;

    m_fetching = false;
    m_descriptor.setTorrentInfo(info);
    setFilesFromInfo(info);
    if (m_name.isEmpty() || (m_name == m_hash))
        m_name = info.name();
    m_status = u"ready"_s;
    rebuildRows();
    emit changed();
}

void AddTorrentDraft::setFilesFromInfo(const BitTorrent::TorrentInfo &info)
{
    m_hasMetadata = true;
    m_files.clear();
    const int count = info.filesCount();
    m_files.reserve(count);
    for (int i = 0; i < count; ++i)
        m_files.append({info.filePath(i).data().replace(u'\\', u'/'), info.fileSize(i), true});
    if (m_name.isEmpty())
        m_name = info.name();
}

QList<int> AddTorrentDraft::filesUnder(const QString &folder) const
{
    QList<int> indexes;
    const QString prefix = folder + u'/';
    for (int i = 0; i < m_files.size(); ++i)
    {
        if (m_files.at(i).path.startsWith(prefix))
            indexes.append(i);
    }
    return indexes;
}

void AddTorrentDraft::rebuildRows()
{
    // file order: natural by path; each file brings the folders above it that were not shown yet
    QList<int> order(m_files.size());
    std::iota(order.begin(), order.end(), 0);
    static const QCollator collator = []
    {
        QCollator c;
        c.setNumericMode(true);
        c.setCaseSensitivity(Qt::CaseInsensitive);
        return c;
    }();
    // folders before files on every level, then natural name order (like Explorer)
    std::sort(order.begin(), order.end(), [this](const int a, const int b)
    {
        const QStringList pa = m_files.at(a).path.split(u'/');
        const QStringList pb = m_files.at(b).path.split(u'/');
        for (qsizetype i = 0; (i < pa.size()) && (i < pb.size()); ++i)
        {
            if (pa.at(i) == pb.at(i))
                continue;
            const bool aFolder = i < (pa.size() - 1);
            const bool bFolder = i < (pb.size() - 1);
            if (aFolder != bFolder)
                return aFolder;
            return collator.compare(pa.at(i), pb.at(i)) < 0;
        }
        return pa.size() > pb.size();
    });

    // per-folder totals
    QHash<QString, qint64> folderSize;
    QHash<QString, int> folderWanted;
    QHash<QString, int> folderTotal;
    for (const FileEntry &f : std::as_const(m_files))
    {
        for (QString dir = parentOf(f.path); !dir.isEmpty(); dir = parentOf(dir))
        {
            folderSize[dir] += f.size;
            folderTotal[dir] += 1;
            folderWanted[dir] += f.wanted ? 1 : 0;
        }
    }

    m_rows.clear();
    m_rowMaps.clear();
    QSet<QString> shown;
    for (const int i : std::as_const(order))
    {
        const FileEntry &f = m_files.at(i);
        const QStringList parts = f.path.split(u'/');
        bool hidden = false;
        QString dir;
        for (int d = 0; d < parts.size() - 1; ++d)
        {
            dir = dir.isEmpty() ? parts.at(d) : (dir + u'/' + parts.at(d));
            if (hidden)
                break;
            if (!shown.contains(dir))
            {
                shown.insert(dir);
                m_rows.append({dir, parts.at(d), d, true, -1});
            }
            if (m_collapsed.contains(dir))
                hidden = true;
        }
        if (!hidden)
            m_rows.append({f.path, parts.last(), static_cast<int>(parts.size()) - 1, false, i});
    }

    for (int r = 0; r < m_rows.size(); ++r)
    {
        const Row &row = m_rows.at(r);
        int state = 0;
        qint64 size = 0;
        if (row.folder)
        {
            const int wanted = folderWanted.value(row.path);
            state = (wanted == 0) ? 0 : (wanted == folderTotal.value(row.path)) ? 2 : 1;
            size = folderSize.value(row.path);
        }
        else
        {
            state = m_files.at(row.file).wanted ? 2 : 0;
            size = m_files.at(row.file).size;
        }
        m_rowMaps.append(QVariantMap {
            {u"row"_s, r}, {u"name"_s, row.name}, {u"path"_s, row.path}, {u"depth"_s, row.depth},
            {u"folder"_s, row.folder}, {u"size"_s, size}, {u"state"_s, state},
            {u"expanded"_s, row.folder && !m_collapsed.contains(row.path)}
        });
    }
    emit filesChanged();
}

void AddTorrentDraft::toggle(const int row)
{
    if ((row < 0) || (row >= m_rows.size()))
        return;

    const Row &r = m_rows.at(row);
    if (r.folder)
    {
        const QList<int> under = filesUnder(r.path);
        bool allWanted = true;
        for (const int i : under)
            allWanted = allWanted && m_files.at(i).wanted;
        for (const int i : under)
            m_files[i].wanted = !allWanted;
    }
    else
    {
        m_files[r.file].wanted = !m_files.at(r.file).wanted;
    }
    rebuildRows();
}

void AddTorrentDraft::setAllWanted(const bool wanted)
{
    for (FileEntry &f : m_files)
        f.wanted = wanted;
    rebuildRows();
}

void AddTorrentDraft::toggleExpanded(const int row)
{
    if ((row < 0) || (row >= m_rows.size()) || !m_rows.at(row).folder)
        return;

    const QString path = m_rows.at(row).path;
    if (m_collapsed.contains(path))
        m_collapsed.remove(path);
    else
        m_collapsed.insert(path);
    rebuildRows();
}

QString AddTorrentDraft::accept()
{
    if (m_status == u"error")
        return m_error;
    if (m_status == u"empty")
        return tr("Nothing to add.");
    if (m_alreadyAdded)
        return tr("This torrent is already in the list.");
    if (m_hasMetadata && (wantedCount() == 0))
        return tr("Choose at least one file.");
    if (m_savePath.isEmpty())
        return tr("Choose a folder.");

    if (m_demo)
    {
        emit added(m_name);
        return {};
    }

    Session *session = Session::instance();
    if (!session)
        return tr("The session is not running.");

    BitTorrent::AddTorrentParams params;
    params.savePath = Path(m_savePath);
    params.useAutoTMM = false;
    params.addStopped = !m_startNow;
    params.sequential = m_sequential;
    params.firstLastPiecePriority = m_firstLast;
    params.skipChecking = m_skipChecking;
    params.contentLayout = (m_contentLayout == u"subfolder") ? BitTorrent::TorrentContentLayout::Subfolder
        : (m_contentLayout == u"noSubfolder") ? BitTorrent::TorrentContentLayout::NoSubfolder
        : BitTorrent::TorrentContentLayout::Original;
    if (!m_category.isEmpty())
    {
        if (!session->categories().contains(m_category))
            session->addCategory(m_category);
        params.category = m_category;
    }
    if (m_hasMetadata)
    {
        params.filePriorities.reserve(m_files.size());
        for (const FileEntry &f : std::as_const(m_files))
            params.filePriorities.append(f.wanted ? BitTorrent::DownloadPriority::Normal : BitTorrent::DownloadPriority::Ignored);
    }

    // the metadata fetch must stop before the same torrent is added for real
    if (m_fetching)
    {
        session->cancelDownloadMetadata(m_descriptor.infoHash().toTorrentID());
        m_fetching = false;
    }
    if (!session->addTorrent(m_descriptor, params))
        return tr("This torrent is already in the list.");

    emit added(m_name);
    return {};
}

void AddTorrentDraft::cancel()
{
    if (m_fetching)
    {
        if (Session *session = Session::instance())
            session->cancelDownloadMetadata(m_descriptor.infoHash().toTorrentID());
        m_fetching = false;
    }
}

void AddTorrentDraft::loadDemo(const QVariantMap &state)
{
    reset();
    m_demo = true;
    m_name = state.value(u"name"_s).toString();
    m_comment = state.value(u"comment"_s).toString();
    m_hash = state.value(u"hash"_s, u"0123456789abcdef0123456789abcdef01234567"_s).toString();
    m_magnet = state.value(u"magnet"_s).toBool();
    m_status = state.value(u"status"_s, u"ready"_s).toString();
    m_alreadyAdded = state.value(u"alreadyAdded"_s).toBool();
    const QVariantList files = state.value(u"files"_s).toList();
    for (const QVariant &v : files)
    {
        const QVariantMap f = v.toMap();
        m_files.append({f.value(u"path"_s).toString(), f.value(u"size"_s).toLongLong(), true});
    }
    m_hasMetadata = !files.isEmpty();
    if (state.contains(u"categories"_s))
        m_categories = state.value(u"categories"_s).toStringList();
    if (state.contains(u"savePath"_s))
        m_savePath = state.value(u"savePath"_s).toString();
    rebuildRows();
    emit changed();
    emit optionsChanged();
}
