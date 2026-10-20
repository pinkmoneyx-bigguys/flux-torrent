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

#include "searchresults.h"

#include <QCollator>

#include "posters.h"
#include "base/global.h"
#include "base/search/searchhandler.h"

SearchResultsModel::SearchResultsModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(this, &QAbstractItemModel::rowsInserted, this, &SearchResultsModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &SearchResultsModel::countChanged);
}

int SearchResultsModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_rows.size());
}

QVariant SearchResultsModel::data(const QModelIndex &index, const int role) const
{
    if (!index.isValid() || (index.row() >= m_rows.size()))
        return {};

    const SearchRow &r = m_rows.at(index.row());
    switch (role)
    {
    case Qt::DisplayRole:
    case NameRole: return r.name;
    case FileUrlRole: return r.fileUrl;
    case DescrLinkRole: return r.descrLink;
    case EngineRole: return r.engine;
    case SiteUrlRole: return r.siteUrl;
    case SizeRole: return r.size;
    case SeedsRole: return r.seeds;
    case LeechersRole: return r.leechers;
    case PublishedRole: return r.published;
    case DownloadedRole: return r.downloaded;
    default: return {};
    }
}

QHash<int, QByteArray> SearchResultsModel::roleNames() const
{
    return {
        {NameRole, "name"},
        {FileUrlRole, "fileUrl"},
        {DescrLinkRole, "descrLink"},
        {EngineRole, "engine"},
        {SiteUrlRole, "siteUrl"},
        {SizeRole, "size"},
        {SeedsRole, "seeds"},
        {LeechersRole, "leechers"},
        {PublishedRole, "published"},
        {DownloadedRole, "downloaded"}
    };
}

const SearchRow *SearchResultsModel::rowAt(const int i) const
{
    return ((i >= 0) && (i < m_rows.size())) ? &m_rows.at(i) : nullptr;
}

void SearchResultsModel::clear()
{
    beginResetModel();
    m_rows.clear();
    endResetModel();
}

void SearchResultsModel::append(const QList<SearchResult> &results)
{
    if (results.isEmpty())
        return;

    const int first = static_cast<int>(m_rows.size());
    beginInsertRows({}, first, first + static_cast<int>(results.size()) - 1);
    for (const SearchResult &result : results)
    {
        SearchRow row;
        row.name = result.fileName;
        row.fileUrl = result.fileUrl;
        row.descrLink = result.descrLink;
        row.engine = result.engineName;
        row.siteUrl = result.siteUrl;
        row.size = result.fileSize;
        row.seeds = result.nbSeeders;
        row.leechers = result.nbLeechers;
        row.published = result.pubDate;
        m_rows.append(row);
    }
    endInsertRows();
}

void SearchResultsModel::setRows(const QVariantList &rows)
{
    beginResetModel();
    m_rows.clear();
    for (const QVariant &v : rows)
    {
        const QVariantMap map = v.toMap();
        SearchRow row;
        row.name = map.value(u"name"_s).toString();
        row.fileUrl = map.value(u"fileUrl"_s).toString();
        row.descrLink = map.value(u"descrLink"_s).toString();
        row.engine = map.value(u"engine"_s).toString();
        row.siteUrl = map.value(u"siteUrl"_s).toString();
        row.size = map.value(u"size"_s, -1).toLongLong();
        row.seeds = map.value(u"seeds"_s, -1).toLongLong();
        row.leechers = map.value(u"leechers"_s, -1).toLongLong();
        if (map.contains(u"publishedSecsAgo"_s))
            row.published = QDateTime::currentDateTime().addSecs(-map.value(u"publishedSecsAgo"_s).toLongLong());
        m_rows.append(row);
    }
    endResetModel();
}

void SearchResultsModel::markDownloaded(const int row)
{
    if ((row < 0) || (row >= m_rows.size()) || m_rows.at(row).downloaded)
        return;

    m_rows[row].downloaded = true;
    emit dataChanged(index(row), index(row), {DownloadedRole});
}

SearchResultsFilter::SearchResultsFilter(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    // results arrive in bursts: group once they settle
    m_groupTimer = new QTimer(this);
    m_groupTimer->setSingleShot(true);
    m_groupTimer->setInterval(120);
    connect(m_groupTimer, &QTimer::timeout, this, &SearchResultsFilter::regroup);
    for (const auto signal : {&QAbstractItemModel::rowsInserted, &QAbstractItemModel::rowsRemoved})
        connect(this, signal, m_groupTimer, qOverload<>(&QTimer::start));
    connect(this, &QAbstractItemModel::modelReset, m_groupTimer, qOverload<>(&QTimer::start));
    connect(this, &QAbstractItemModel::layoutChanged, m_groupTimer, qOverload<>(&QTimer::start));
    connect(this, &QAbstractItemModel::dataChanged, m_groupTimer, qOverload<>(&QTimer::start));

    setDynamicSortFilter(true);
    connect(this, &QAbstractItemModel::rowsInserted, this, &SearchResultsFilter::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &SearchResultsFilter::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &SearchResultsFilter::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &SearchResultsFilter::countChanged);
    // the sort survives a new source (sourceModel is set from QML after the properties)
    connect(this, &QAbstractProxyModel::sourceModelChanged, this, &SearchResultsFilter::applySort);
}

QString SearchResultsFilter::search() const
{
    return m_search;
}

void SearchResultsFilter::setSearch(const QString &search)
{
    if (search == m_search)
        return;

    beginFilterChange();
    m_search = search;
    m_words = search.split(u' ', Qt::SkipEmptyParts);
    endFilterChange(Direction::Rows);
    emit filterChanged();
}

bool SearchResultsFilter::seededOnly() const
{
    return m_seededOnly;
}

void SearchResultsFilter::setSeededOnly(const bool on)
{
    if (on == m_seededOnly)
        return;

    beginFilterChange();
    m_seededOnly = on;
    endFilterChange(Direction::Rows);
    emit filterChanged();
}

QString SearchResultsFilter::sortKey() const
{
    return m_sortKey;
}

void SearchResultsFilter::setSortKey(const QString &key)
{
    if (key == m_sortKey)
        return;

    m_sortKey = key;
    applySort();
    emit sortChanged();
}

bool SearchResultsFilter::descending() const
{
    return m_descending;
}

void SearchResultsFilter::setDescending(const bool descending)
{
    if (descending == m_descending)
        return;

    m_descending = descending;
    applySort();
    emit sortChanged();
}

int SearchResultsFilter::count() const
{
    return rowCount();
}

int SearchResultsFilter::sourceRow(const int row) const
{
    const QModelIndex source = mapToSource(index(row, 0));
    return source.isValid() ? source.row() : -1;
}

bool SearchResultsFilter::filterAcceptsRow(const int sourceRow, const QModelIndex &) const
{
    const auto *model = qobject_cast<const SearchResultsModel *>(sourceModel());
    const SearchRow *row = model ? model->rowAt(sourceRow) : nullptr;
    if (!row)
        return false;

    if (m_seededOnly && (row->seeds <= 0))
        return false;

    for (const QString &word : m_words)
    {
        if (!row->name.contains(word, Qt::CaseInsensitive))
            return false;
    }
    return true;
}

bool SearchResultsFilter::lessThan(const QModelIndex &left, const QModelIndex &right) const
{
    const QVariant a = left.data(sortRole());
    const QVariant b = right.data(sortRole());
    if (a.typeId() == QMetaType::QString)
    {
        static const QCollator collator = []
        {
            QCollator c;
            c.setNumericMode(true);
            c.setCaseSensitivity(Qt::CaseInsensitive);
            return c;
        }();
        return collator.compare(a.toString(), b.toString()) < 0;
    }
    return QVariant::compare(a, b) == QPartialOrdering::Less;
}

void SearchResultsFilter::applySort()
{
    const QHash<int, QByteArray> roles = sourceModel() ? sourceModel()->roleNames() : QHash<int, QByteArray> {};
    const int role = roles.key(m_sortKey.toLatin1(), -1);
    if (role < 0)
    {
        sort(-1);
        return;
    }
    setSortRole(role);
    sort(0, m_descending ? Qt::DescendingOrder : Qt::AscendingOrder);
}

QVariantList SearchResultsFilter::groups() const
{
    return m_groups;
}

void SearchResultsFilter::regroup()
{
    const auto *results = qobject_cast<const SearchResultsModel *>(sourceModel());
    QList<QVariantMap> groups;
    QHash<QString, qsizetype> indexOf;
    static const QStringList qualityOrder {u"2160p"_s, u"1080p"_s, u"720p"_s, u"576p"_s, u"480p"_s};

    // Parse every shown release first: a release that names no year joins the film of the same title
    // that does (the year most of its releases give), instead of making a card of its own
    struct Parsed
    {
        int source;
        const SearchRow *row;
        FilmInfo film;
    };
    QList<Parsed> parsed;
    QHash<QString, QHash<int, int>> yearsOfTitle;  // title part of the key → year → releases
    for (int i = 0; results && (i < rowCount()); ++i)
    {
        const int source = mapToSource(index(i, 0)).row();
        const SearchRow *r = results->rowAt(source);
        if (!r)
            continue;
        Parsed p {source, r, FilmInfo::parse(r->name)};
        if (p.film.year > 0)
            ++yearsOfTitle[p.film.key.section(u'|', 0, 0)][p.film.year];
        parsed.append(p);
    }
    for (Parsed &p : parsed)
    {
        if (p.film.year > 0)
            continue;
        const QString titlePart = p.film.key.section(u'|', 0, 0);
        const QHash<int, int> years = yearsOfTitle.value(titlePart);
        int bestYear = 0;
        int bestCount = 0;
        for (auto it = years.cbegin(); it != years.cend(); ++it)
        {
            if (it.value() > bestCount)
            {
                bestYear = it.key();
                bestCount = it.value();
            }
        }
        if (bestYear > 0)
        {
            p.film.year = bestYear;
            p.film.key = titlePart + u'|' + QString::number(bestYear);
        }
    }

    for (const Parsed &p : std::as_const(parsed))
    {
        const int source = p.source;
        const SearchRow *r = p.row;
        const FilmInfo &film = p.film;

        qsizetype g = indexOf.value(film.key, -1);
        if (g < 0)
        {
            g = groups.size();
            indexOf.insert(film.key, g);
            QVariantMap group = film.toMap();
            group.insert(u"count"_s, 0);
            group.insert(u"seeds"_s, -1);
            group.insert(u"minSize"_s, -1);
            group.insert(u"maxSize"_s, -1);
            group.insert(u"qualities"_s, QStringList {});
            group.insert(u"releases"_s, QVariantList {});
            groups.append(group);
        }
        QVariantMap &group = groups[g];
        group[u"count"_s] = group.value(u"count"_s).toInt() + 1;
        group[u"seeds"_s] = std::max(group.value(u"seeds"_s).toLongLong(), r->seeds);
        if (r->size >= 0)
        {
            const qint64 lo = group.value(u"minSize"_s).toLongLong();
            group[u"minSize"_s] = (lo < 0) ? r->size : std::min(lo, r->size);
            group[u"maxSize"_s] = std::max(group.value(u"maxSize"_s).toLongLong(), r->size);
        }
        if (!film.quality.isEmpty())
        {
            QStringList qualities = group.value(u"qualities"_s).toStringList();
            if (!qualities.contains(film.quality))
            {
                qualities.append(film.quality);
                std::sort(qualities.begin(), qualities.end(), [](const QString &a, const QString &b)
                {
                    return qualityOrder.indexOf(a) < qualityOrder.indexOf(b);
                });
                group[u"qualities"_s] = qualities;
            }
        }
        QVariantList releases = group.value(u"releases"_s).toList();
        releases.append(QVariantMap {
            {u"row"_s, source}, {u"name"_s, r->name}, {u"size"_s, r->size}, {u"seeds"_s, r->seeds},
            {u"leechers"_s, r->leechers}, {u"engine"_s, r->engine}, {u"fileUrl"_s, r->fileUrl},
            {u"published"_s, r->published}, {u"downloaded"_s, r->downloaded}, {u"quality"_s, film.quality}
        });
        group[u"releases"_s] = releases;
    }

    m_groups.clear();
    for (const QVariantMap &group : std::as_const(groups))
        m_groups.append(group);
    emit groupsChanged();
}
