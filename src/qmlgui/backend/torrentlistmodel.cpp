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

#include "torrentlistmodel.h"

#include <algorithm>

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRandomGenerator>
#include <QSet>
#include <QTimer>

#include "base/bittorrent/addtorrentparams.h"
#include "base/bittorrent/infohash.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/bittorrent/torrentdescriptor.h"
#include "base/global.h"
#include "base/path.h"
#include "base/tagset.h"

using BitTorrent::Torrent;
using BitTorrent::TorrentState;

namespace
{
    QString joinTags(const TagSet &tags)
    {
        QStringList list;
        for (const Tag &tag : tags)
            list.append(tag.toString());
        return list.join(u", "_s);
    }

    QList<BitTorrent::TorrentID> idsOf(const QList<Torrent *> &torrents)
    {
        QList<BitTorrent::TorrentID> ids;
        ids.reserve(torrents.size());
        for (const Torrent *torrent : torrents)
            ids.append(torrent->id());
        return ids;
    }
}

TorrentRow TorrentRow::fromTorrent(const Torrent *torrent)
{
    TorrentRow row;
    row.id = torrent->id().toString();
    row.name = torrent->name();
    row.state = TorrentListModel::stateKey(static_cast<int>(torrent->state()));
    row.category = torrent->category();
    row.tags = joinTags(torrent->tags());
    row.savePath = torrent->savePath().toString();
    row.error = torrent->error();
    row.size = torrent->wantedSize();
    row.totalSize = torrent->totalSize();
    row.done = torrent->completedSize();
    row.downloaded = torrent->totalDownload();
    row.uploaded = torrent->totalUpload();
    row.dlSpeed = torrent->downloadPayloadRate();
    row.upSpeed = torrent->uploadPayloadRate();
    row.eta = torrent->eta();
    row.progress = torrent->progress();
    row.ratio = torrent->realRatio();
    row.seeds = torrent->seedsCount();
    row.seedsTotal = torrent->totalSeedsCount();
    row.peers = torrent->peersCount() - torrent->seedsCount();
    row.peersTotal = torrent->totalPeersCount();
    row.queuePosition = torrent->queuePosition();
    row.added = torrent->addedTime();
    row.completed = torrent->completedTime();
    return row;
}

TorrentRow TorrentRow::fromVariant(const QVariantMap &map)
{
    TorrentRow row;
    row.id = map.value(u"id"_s).toString();
    row.name = map.value(u"name"_s).toString();
    row.state = map.value(u"state"_s, u"stoppedDl"_s).toString();
    row.category = map.value(u"category"_s).toString();
    row.tags = map.value(u"tags"_s).toString();
    row.savePath = map.value(u"savePath"_s).toString();
    row.error = map.value(u"error"_s).toString();
    row.size = map.value(u"size"_s).toLongLong();
    row.totalSize = map.value(u"totalSize"_s, row.size).toLongLong();
    row.progress = map.value(u"progress"_s).toReal();
    row.done = map.value(u"done"_s, static_cast<qint64>(row.size * row.progress)).toLongLong();
    row.downloaded = map.value(u"downloaded"_s, row.done).toLongLong();
    row.uploaded = map.value(u"uploaded"_s).toLongLong();
    row.dlSpeed = map.value(u"dlSpeed"_s).toLongLong();
    row.upSpeed = map.value(u"upSpeed"_s).toLongLong();
    row.eta = map.value(u"eta"_s, 8640000).toLongLong();
    row.ratio = map.value(u"ratio"_s).toReal();
    row.seeds = map.value(u"seeds"_s).toInt();
    row.seedsTotal = map.value(u"seedsTotal"_s).toInt();
    row.peers = map.value(u"peers"_s).toInt();
    row.peersTotal = map.value(u"peersTotal"_s).toInt();
    row.queuePosition = map.value(u"queuePosition"_s, -1).toInt();
    const qint64 addedAgo = map.value(u"addedSecsAgo"_s, 3600).toLongLong();
    row.added = QDateTime::currentDateTime().addSecs(-addedAgo);
    for (const QString &key : {u"files"_s, u"trackers"_s, u"peerList"_s, u"pieces"_s})
    {
        if (map.contains(key))
            row.extra.insert(key, map.value(key));
    }
    return row;
}

namespace
{
    const int HISTORY_INTERVAL = 1000;
    const int HISTORY_SIZE = 300;  // five minutes
}

void TorrentListModel::SpeedSeries::append(const qreal d, const qreal u, const int limit)
{
    down.append(d);
    up.append(u);
    if (down.size() > limit)
    {
        down.removeFirst();
        up.removeFirst();
    }
}

TorrentListModel::TorrentListModel(QObject *parent)
    : QAbstractListModel(parent)
    , m_historyTimer {new QTimer(this)}
{
    updateCounts();

    m_historyTimer->setInterval(HISTORY_INTERVAL);
    m_historyTimer->setTimerType(Qt::PreciseTimer);
    connect(m_historyTimer, &QTimer::timeout, this, &TorrentListModel::sampleHistory);
    m_historyTimer->start();

    // Development aid for window captures: a JSON array of rows instead of the session's torrents
    if (const QString demo = qEnvironmentVariable("FLUX_DEMO_TORRENTS"); !demo.isEmpty())
    {
        QFile file {demo};
        if (file.open(QIODevice::ReadOnly))
        {
            setRows(QJsonDocument::fromJson(file.readAll()).array().toVariantList());
            return;
        }
    }

    auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    connect(session, &BitTorrent::Session::torrentsLoaded, this, &TorrentListModel::onTorrentsLoaded);
    connect(session, &BitTorrent::Session::torrentAdded, this, [this](Torrent *torrent)
    {
        onTorrentsLoaded({torrent});
    });
    connect(session, &BitTorrent::Session::torrentAboutToBeRemoved, this, &TorrentListModel::onTorrentAboutToBeRemoved);
    connect(session, &BitTorrent::Session::torrentsUpdated, this, &TorrentListModel::onTorrentsUpdated);

    onTorrentsLoaded(session->torrents());
}

TorrentListModel *TorrentListModel::create(QQmlEngine *, QJSEngine *)
{
    return new TorrentListModel;
}

QString TorrentListModel::stateKey(const int torrentState)
{
    switch (static_cast<TorrentState>(torrentState))
    {
    case TorrentState::ForcedDownloading:
    case TorrentState::Downloading:
        return u"downloading"_s;
    case TorrentState::ForcedDownloadingMetadata:
    case TorrentState::DownloadingMetadata:
        return u"metadata"_s;
    case TorrentState::StalledDownloading:
        return u"stalledDl"_s;
    case TorrentState::ForcedUploading:
    case TorrentState::Uploading:
        return u"seeding"_s;
    case TorrentState::StalledUploading:
        return u"stalledUp"_s;
    case TorrentState::QueuedDownloading:
        return u"queuedDl"_s;
    case TorrentState::QueuedUploading:
        return u"queuedUp"_s;
    case TorrentState::CheckingResumeData:
    case TorrentState::CheckingUploading:
    case TorrentState::CheckingDownloading:
        return u"checking"_s;
    case TorrentState::StoppedDownloading:
        return u"stoppedDl"_s;
    case TorrentState::StoppedUploading:
        return u"stoppedUp"_s;
    case TorrentState::Moving:
        return u"moving"_s;
    case TorrentState::MissingFiles:
        return u"missing"_s;
    case TorrentState::Error:
    default:
        return u"error"_s;
    }
}

bool TorrentListModel::matchesStatus(const TorrentRow &row, const QString &status)
{
    const QString &s = row.state;
    if (status == u"downloading")
        return (s == u"downloading") || (s == u"metadata") || (s == u"stalledDl") || (s == u"queuedDl")
            || ((s == u"checking") && (row.progress < 1));
    if (status == u"seeding")
        return (s == u"seeding") || (s == u"stalledUp") || (s == u"queuedUp");
    if (status == u"completed")
        return (row.progress >= 1) || (s == u"seeding") || (s == u"stalledUp") || (s == u"queuedUp") || (s == u"stoppedUp");
    if (status == u"stopped")
        return (s == u"stoppedDl") || (s == u"stoppedUp");
    if (status == u"active")
        return (row.dlSpeed > 0) || (row.upSpeed > 0);
    if (status == u"errored")
        return (s == u"error") || (s == u"missing");
    return true;
}

int TorrentListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_rows.size());
}

QVariant TorrentListModel::data(const QModelIndex &index, const int role) const
{
    if (!index.isValid() || (index.row() >= m_rows.size()))
        return {};

    const TorrentRow &r = m_rows.at(index.row());
    switch (role)
    {
    case Qt::DisplayRole:
    case NameRole: return r.name;
    case IdRole: return r.id;
    case StateRole: return r.state;
    case CategoryRole: return r.category;
    case TagsRole: return r.tags;
    case SavePathRole: return r.savePath;
    case ErrorRole: return r.error;
    case SizeRole: return r.size;
    case TotalSizeRole: return r.totalSize;
    case DoneRole: return r.done;
    case DownloadedRole: return r.downloaded;
    case UploadedRole: return r.uploaded;
    case DlSpeedRole: return r.dlSpeed;
    case UpSpeedRole: return r.upSpeed;
    case EtaRole: return r.eta;
    case ProgressRole: return r.progress;
    case RatioRole: return r.ratio;
    case SeedsRole: return r.seeds;
    case SeedsTotalRole: return r.seedsTotal;
    case PeersRole: return r.peers;
    case PeersTotalRole: return r.peersTotal;
    case QueuePositionRole: return r.queuePosition;
    case AddedRole: return r.added;
    case CompletedRole: return r.completed;
    default: return {};
    }
}

QHash<int, QByteArray> TorrentListModel::roleNames() const
{
    return {
        {IdRole, "torrentId"},
        {NameRole, "name"},
        {StateRole, "state"},
        {CategoryRole, "category"},
        {TagsRole, "tags"},
        {SavePathRole, "savePath"},
        {ErrorRole, "error"},
        {SizeRole, "size"},
        {TotalSizeRole, "totalSize"},
        {DoneRole, "done"},
        {DownloadedRole, "downloaded"},
        {UploadedRole, "uploaded"},
        {DlSpeedRole, "dlSpeed"},
        {UpSpeedRole, "upSpeed"},
        {EtaRole, "eta"},
        {ProgressRole, "progress"},
        {RatioRole, "ratio"},
        {SeedsRole, "seeds"},
        {SeedsTotalRole, "seedsTotal"},
        {PeersRole, "peers"},
        {PeersTotalRole, "peersTotal"},
        {QueuePositionRole, "queuePosition"},
        {AddedRole, "added"},
        {CompletedRole, "completed"}
    };
}

QVariantMap TorrentListModel::counts() const
{
    return m_counts;
}

const TorrentRow *TorrentListModel::row(const QString &id) const
{
    const auto it = m_index.constFind(id);
    return (it != m_index.cend()) ? &m_rows.at(it.value()) : nullptr;
}

const TorrentRow *TorrentListModel::rowAt(const int i) const
{
    return ((i >= 0) && (i < m_rows.size())) ? &m_rows.at(i) : nullptr;
}

void TorrentListModel::setRows(const QVariantList &rows)
{
    m_detached = true;
    beginResetModel();
    m_rows.clear();
    for (const QVariant &v : rows)
        m_rows.append(TorrentRow::fromVariant(v.toMap()));
    reindex(0);
    endResetModel();
    updateCounts();
}

QStringList TorrentListModel::allIds() const
{
    QStringList ids;
    ids.reserve(m_rows.size());
    for (const TorrentRow &r : m_rows)
        ids.append(r.id);
    return ids;
}

QVariantMap TorrentListModel::get(const QString &id) const
{
    const TorrentRow *r = row(id);
    if (!r)
        return {};

    QVariantMap map;
    const int i = m_index.value(id);
    const QHash<int, QByteArray> roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        map.insert(QString::fromLatin1(it.value()), data(index(i), it.key()));
    map.insert(u"extra"_s, r->extra);
    return map;
}

void TorrentListModel::onTorrentsLoaded(const QList<Torrent *> &torrents)
{
    if (m_detached)
        return;

    QList<TorrentRow> rows;
    rows.reserve(torrents.size());
    for (const Torrent *torrent : torrents)
    {
        if (!m_index.contains(torrent->id().toString()))
            rows.append(TorrentRow::fromTorrent(torrent));
    }
    appendRows(rows);
}

void TorrentListModel::onTorrentAboutToBeRemoved(Torrent *torrent)
{
    if (m_detached)
        return;

    const auto it = m_index.constFind(torrent->id().toString());
    if (it == m_index.cend())
        return;

    const int i = it.value();
    beginRemoveRows({}, i, i);
    m_rows.removeAt(i);
    m_index.remove(torrent->id().toString());
    reindex(i);
    endRemoveRows();
    updateCounts();
}

void TorrentListModel::onTorrentsUpdated(const QList<Torrent *> &torrents)
{
    if (m_detached)
        return;

    for (const Torrent *torrent : torrents)
    {
        const auto it = m_index.constFind(torrent->id().toString());
        if (it == m_index.cend())
            continue;

        const int i = it.value();
        m_rows[i] = TorrentRow::fromTorrent(torrent);
        emit dataChanged(index(i), index(i));
    }
    updateCounts();
}

void TorrentListModel::appendRows(const QList<TorrentRow> &rows)
{
    if (rows.isEmpty())
        return;

    const int first = static_cast<int>(m_rows.size());
    beginInsertRows({}, first, first + static_cast<int>(rows.size()) - 1);
    m_rows.append(rows);
    reindex(first);
    endInsertRows();
    updateCounts();
}

void TorrentListModel::reindex(const int from)
{
    if (from == 0)
        m_index.clear();
    for (int i = from; i < m_rows.size(); ++i)
        m_index.insert(m_rows.at(i).id, i);
}

void TorrentListModel::updateCounts()
{
    static const QStringList statuses {u"all"_s, u"downloading"_s, u"seeding"_s, u"completed"_s, u"stopped"_s, u"active"_s, u"errored"_s};

    QVariantMap counts;
    for (const QString &status : statuses)
    {
        int n = 0;
        for (const TorrentRow &r : std::as_const(m_rows))
            n += matchesStatus(r, status) ? 1 : 0;
        counts.insert(status, n);
    }
    if (counts != m_counts)
    {
        m_counts = counts;
        emit countsChanged();
    }
}

QList<Torrent *> TorrentListModel::torrentsOf(const QStringList &ids) const
{
    QList<Torrent *> torrents;
    const auto *session = BitTorrent::Session::instance();
    if (!session)
        return torrents;

    for (const QString &id : ids)
    {
        if (Torrent *torrent = session->getTorrent(BitTorrent::TorrentID::fromString(id)))
            torrents.append(torrent);
    }
    return torrents;
}

void TorrentListModel::start(const QStringList &ids)
{
    for (Torrent *torrent : torrentsOf(ids))
        torrent->start();
}

void TorrentListModel::stop(const QStringList &ids)
{
    for (Torrent *torrent : torrentsOf(ids))
        torrent->stop();
}

void TorrentListModel::forceStart(const QStringList &ids)
{
    for (Torrent *torrent : torrentsOf(ids))
        torrent->start(BitTorrent::TorrentOperatingMode::Forced);
}

void TorrentListModel::remove(const QStringList &ids, const bool deleteFiles)
{
    auto *session = BitTorrent::Session::instance();
    if (!session)
        return;

    const auto option = deleteFiles ? BitTorrent::TorrentRemoveOption::RemoveContent : BitTorrent::TorrentRemoveOption::KeepContent;
    for (const Torrent *torrent : torrentsOf(ids))
        session->removeTorrent(torrent->id(), option);
}

void TorrentListModel::recheck(const QStringList &ids)
{
    for (Torrent *torrent : torrentsOf(ids))
        torrent->forceRecheck();
}

void TorrentListModel::reannounce(const QStringList &ids)
{
    for (Torrent *torrent : torrentsOf(ids))
        torrent->forceReannounce();
}

void TorrentListModel::queueTop(const QStringList &ids)
{
    if (auto *session = BitTorrent::Session::instance())
        session->topTorrentsQueuePos(idsOf(torrentsOf(ids)));
}

void TorrentListModel::queueUp(const QStringList &ids)
{
    if (auto *session = BitTorrent::Session::instance())
        session->increaseTorrentsQueuePos(idsOf(torrentsOf(ids)));
}

void TorrentListModel::queueDown(const QStringList &ids)
{
    if (auto *session = BitTorrent::Session::instance())
        session->decreaseTorrentsQueuePos(idsOf(torrentsOf(ids)));
}

void TorrentListModel::queueBottom(const QStringList &ids)
{
    if (auto *session = BitTorrent::Session::instance())
        session->bottomTorrentsQueuePos(idsOf(torrentsOf(ids)));
}

int TorrentListModel::copyMagnets(const QStringList &ids)
{
    QStringList links;
    for (const Torrent *torrent : torrentsOf(ids))
        links.append(torrent->createMagnetURI());
    if (!links.isEmpty())
        QGuiApplication::clipboard()->setText(links.join(u'\n'));
    return static_cast<int>(links.size());
}

void TorrentListModel::openFolder(const QString &id)
{
    const QList<Torrent *> torrents = torrentsOf({id});
    if (torrents.isEmpty())
        return;

    const Torrent *torrent = torrents.first();
    const Path content = torrent->contentPath();
    if (content.exists() && !QFileInfo(content.data()).isDir())
    {
        // Explorer opens the folder with the file selected
        QProcess::startDetached(u"explorer.exe"_s, {u"/select,"_s + content.toString()});
        return;
    }
    const Path folder = content.exists() ? content : torrent->savePath();
    QDesktopServices::openUrl(QUrl::fromLocalFile(folder.data()));
}

QString TorrentListModel::addFile(const QUrl &fileUrl)
{
    auto *session = BitTorrent::Session::instance();
    if (!session)
        return tr("The session is not running.");

    const auto descriptor = BitTorrent::TorrentDescriptor::loadFromFile(Path(fileUrl.toLocalFile()));
    if (!descriptor)
        return descriptor.error();
    return session->addTorrent(descriptor.value()) ? QString() : tr("This torrent is already in the list.");
}

QVariantMap TorrentListModel::demoAddState() const
{
    QFile file {qEnvironmentVariable("FLUX_DEMO_ADD")};
    if (file.fileName().isEmpty() || !file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
}

QString TorrentListModel::addLink(const QString &link)
{
    auto *session = BitTorrent::Session::instance();
    if (!session)
        return tr("The session is not running.");

    const auto descriptor = BitTorrent::TorrentDescriptor::parse(link.trimmed());
    if (!descriptor)
        return descriptor.error();
    return session->addTorrent(descriptor.value()) ? QString() : tr("This torrent is already in the list.");
}

qint64 TorrentListModel::historySampledAt() const
{
    return m_sampledAt;
}

int TorrentListModel::historyInterval() const
{
    return HISTORY_INTERVAL;
}

int TorrentListModel::historySize() const
{
    return HISTORY_SIZE;
}

void TorrentListModel::sampleHistory()
{
    qreal totalDown = 0;
    qreal totalUp = 0;
    QSet<QString> present;
    for (const TorrentRow &r : std::as_const(m_rows))
    {
        qreal down = r.dlSpeed;
        qreal up = r.upSpeed;
        // demo rows hold still: a slow drift (a few per cent a second, within ±15 %) gives the graph life
        if (m_detached)
        {
            qreal &drift = m_demoDrift[r.id];
            if (drift == 0)
                drift = 1;
            drift = std::clamp(drift + (QRandomGenerator::global()->generateDouble() - 0.5) * 0.06, 0.85, 1.15);
            down *= drift;
            up *= (2 - drift);
        }
        m_history[r.id].append(down, up, HISTORY_SIZE);
        present.insert(r.id);
        totalDown += down;
        totalUp += up;
    }
    // forget the torrents that are gone
    for (auto it = m_history.begin(); it != m_history.end();)
        it = present.contains(it.key()) ? std::next(it) : m_history.erase(it);
    m_totalHistory.append(totalDown, totalUp, HISTORY_SIZE);

    m_sampledAt = QDateTime::currentMSecsSinceEpoch();
    emit historySampled();
}

QVariantMap TorrentListModel::speedHistory(const QString &id) const
{
    const SpeedSeries *series = id.isEmpty() ? &m_totalHistory : nullptr;
    if (!series)
    {
        const auto it = m_history.constFind(id);
        if (it == m_history.cend())
            return {{u"down"_s, QVariantList {}}, {u"up"_s, QVariantList {}}};
        series = &it.value();
    }
    QVariantList down;
    QVariantList up;
    down.reserve(series->down.size());
    up.reserve(series->up.size());
    for (const qreal v : series->down)
        down.append(v);
    for (const qreal v : series->up)
        up.append(v);
    return {{u"down"_s, down}, {u"up"_s, up}};
}
