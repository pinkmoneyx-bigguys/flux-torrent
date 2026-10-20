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

#include "torrentfiltermodel.h"

#include <QCollator>

#include "base/global.h"
#include "torrentlistmodel.h"

TorrentFilterModel::TorrentFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
    setDynamicSortFilter(true);
    connect(this, &QAbstractItemModel::rowsInserted, this, &TorrentFilterModel::countChanged);
    connect(this, &QAbstractItemModel::rowsRemoved, this, &TorrentFilterModel::countChanged);
    connect(this, &QAbstractItemModel::modelReset, this, &TorrentFilterModel::countChanged);
    connect(this, &QAbstractItemModel::layoutChanged, this, &TorrentFilterModel::countChanged);
}

QString TorrentFilterModel::status() const
{
    return m_status;
}

void TorrentFilterModel::setStatus(const QString &status)
{
    if (status == m_status)
        return;

    beginFilterChange();
    m_status = status;
    endFilterChange(Direction::Rows);
    emit statusChanged();
}

QString TorrentFilterModel::search() const
{
    return m_search;
}

void TorrentFilterModel::setSearch(const QString &search)
{
    if (search == m_search)
        return;

    beginFilterChange();
    m_search = search;
    m_words = search.split(u' ', Qt::SkipEmptyParts);
    endFilterChange(Direction::Rows);
    emit searchChanged();
}

QString TorrentFilterModel::sortKey() const
{
    return m_sortKey;
}

void TorrentFilterModel::setSortKey(const QString &key)
{
    if (key == m_sortKey)
        return;

    m_sortKey = key;
    applySort();
    emit sortChanged();
}

bool TorrentFilterModel::descending() const
{
    return m_descending;
}

void TorrentFilterModel::setDescending(const bool descending)
{
    if (descending == m_descending)
        return;

    m_descending = descending;
    applySort();
    emit sortChanged();
}

int TorrentFilterModel::count() const
{
    return rowCount();
}

QString TorrentFilterModel::idAt(const int row) const
{
    return data(index(row, 0), TorrentListModel::IdRole).toString();
}

int TorrentFilterModel::rowOf(const QString &id) const
{
    for (int i = 0; i < rowCount(); ++i)
    {
        if (idAt(i) == id)
            return i;
    }
    return -1;
}

QStringList TorrentFilterModel::idsBetween(const int first, const int last) const
{
    QStringList ids;
    for (int i = std::max(0, std::min(first, last)); i <= std::min(rowCount() - 1, std::max(first, last)); ++i)
        ids.append(idAt(i));
    return ids;
}

bool TorrentFilterModel::filterAcceptsRow(const int sourceRow, const QModelIndex &) const
{
    const auto *model = qobject_cast<const TorrentListModel *>(sourceModel());
    const TorrentRow *row = model ? model->rowAt(sourceRow) : nullptr;
    if (!row)
        return false;

    if (!TorrentListModel::matchesStatus(*row, m_status))
        return false;

    for (const QString &word : m_words)
    {
        if (!row->name.contains(word, Qt::CaseInsensitive) && !row->category.contains(word, Qt::CaseInsensitive)
            && !row->tags.contains(word, Qt::CaseInsensitive))
            return false;
    }
    return true;
}

bool TorrentFilterModel::lessThan(const QModelIndex &left, const QModelIndex &right) const
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

void TorrentFilterModel::applySort()
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
