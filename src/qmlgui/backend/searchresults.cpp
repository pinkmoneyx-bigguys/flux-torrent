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
