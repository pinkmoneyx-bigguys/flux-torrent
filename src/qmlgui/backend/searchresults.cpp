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

#include <algorithm>
#include <utility>

#include <QCollator>
#include <QRegularExpression>

#include "base/global.h"
#include "base/search/searchhandler.h"

namespace
{
    // a source's titles are sometimes the release's whole name, genres and all ("… [ONA] [10 из 10]
    // [2022, киберпанк, …]"): only a title counts as one
    bool plausibleTitle(const QString &title)
    {
        return !title.isEmpty() && (title.size() <= 80) && !title.contains(u'[') && !title.contains(u'|');
    }
}

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

void SearchResultsModel::append(const QList<JacRedResult> &results)
{
    QList<SearchResult> plain;
    plain.reserve(results.size());
    for (const JacRedResult &r : results)
        plain.append(r.result);
    const qsizetype first = m_rows.size();
    append(plain);
    for (qsizetype i = 0; (i < results.size()) && ((first + i) < m_rows.size()); ++i)
        m_rows[first + i].meta = results.at(i).meta;
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
        // what JacRed would know
        row.meta.title = map.value(u"metaTitle"_s).toString();
        row.meta.original = map.value(u"metaOriginal"_s).toString();
        row.meta.year = map.value(u"metaYear"_s).toInt();
        row.meta.voices = map.value(u"voices"_s).toStringList();
        for (const QVariant &season : map.value(u"seasons"_s).toList())
            row.meta.seasons.append(season.toInt());
        row.meta.video = map.value(u"video"_s).toString();
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
    // the source's rows too: hidden rows still need their posters looked up
    connect(this, &QAbstractProxyModel::sourceModelChanged, this, [this]
    {
        if (!sourceModel())
            return;
        connect(sourceModel(), &QAbstractItemModel::rowsInserted, m_groupTimer, qOverload<>(&QTimer::start));
        connect(sourceModel(), &QAbstractItemModel::modelReset, m_groupTimer, qOverload<>(&QTimer::start));
    });
    // a poster found: with postersOnly its film's releases show up
    connect(Posters::instance(), &Posters::revisionChanged, this, [this]
    {
        if (m_postersOnly)
            invalidateFilter();
    });

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

    if (m_exact && !matchesQuery(*row))
        return false;

    if (m_postersOnly && Posters::instance()->poster(FilmInfo::parse(row->name).key).isEmpty())
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

bool SearchResultsFilter::postersOnly() const
{
    return m_postersOnly;
}

void SearchResultsFilter::setPostersOnly(const bool on)
{
    if (on == m_postersOnly)
        return;
    m_postersOnly = on;
    invalidateFilter();
    emit filterChanged();
}

void SearchResultsFilter::resolveFilms()
{
    const auto *results = qobject_cast<const SearchResultsModel *>(sourceModel());
    m_resolved.clear();
    if (!results)
        return;

    // every release, shown or not: the films don't change with the switches
    QList<FilmInfo> films;
    films.reserve(results->rowCount());
    QHash<QString, QString> nameKeys;  // a release's key from its name alone → from what its source knows
    for (int i = 0; i < results->rowCount(); ++i)
    {
        if (const SearchRow *r = results->rowAt(i))
        {
            films.append(filmOfRelease(r->name, r->meta));
            // the list view asks for posters by the name alone
            if (const QString byName = FilmInfo::parse(r->name).key; byName != films.last().key)
                nameKeys.insert(byName, films.last().key);
        }
    }

    // A release that names no year joins the film of the same title that does (the year most of its
    // releases give), instead of making a card of its own
    QHash<QString, QHash<int, int>> yearsOfTitle;  // title part of the key → year → releases
    for (const FilmInfo &film : std::as_const(films))
    {
        if (film.year > 0)
            ++yearsOfTitle[film.key.section(u'|', 0, 0)][film.year];
    }
    QHash<QString, FilmInfo> resolved;  // key as parsed → the film
    for (const FilmInfo &film : std::as_const(films))
    {
        if (resolved.contains(film.key))
            continue;
        FilmInfo f = film;
        if (f.year <= 0)
        {
            const QString titlePart = f.key.section(u'|', 0, 0);
            const QHash<int, int> years = yearsOfTitle.value(titlePart);
            int bestCount = 0;
            for (auto it = years.cbegin(); it != years.cend(); ++it)
            {
                if (it.value() > bestCount)
                {
                    f.year = it.key();
                    bestCount = it.value();
                }
            }
            if (f.year > 0)
                f.key = titlePart + u'|' + QString::number(f.year);
        }
        resolved.insert(film.key, f);
    }

    // A release named only in Russian ("Космическая Элла") joins the film of that Russian title that also
    // gives an original one ("Космическая Элла / Interstellar Ella [2022]"): of its year or, with none,
    // the one with the most releases
    struct Known
    {
        FilmInfo film;
        int releases = 0;
    };
    QHash<QString, QList<Known>> withOriginal;  // comparable local title → films
    for (const FilmInfo &parsed : std::as_const(films))
    {
        const FilmInfo &film = resolved[parsed.key];
        if (film.original.isEmpty() || (FilmInfo::comparable(film.original) == FilmInfo::comparable(film.title)))
            continue;
        QList<Known> &known = withOriginal[FilmInfo::comparable(film.title)];
        const auto it = std::find_if(known.begin(), known.end(), [&film](const Known &k) { return k.film.key == film.key; });
        if (it == known.end())
            known.append({film, 1});
        else
            ++it->releases;
    }
    for (FilmInfo &film : resolved)
    {
        if (!film.original.isEmpty())
            continue;
        const Known *best = nullptr;
        const QList<Known> known = withOriginal.value(FilmInfo::comparable(film.title));
        for (const Known &k : known)
        {
            if ((film.year > 0) && (k.film.year != film.year))
                continue;
            if (!best || (k.releases > best->releases))
                best = &k;
        }
        if (best)
        {
            film.key = best->film.key;
            film.original = best->film.original;
            film.year = best->film.year;
        }
    }

    // posters: one look-up a film, and a release finds its film's poster by its own key too
    Posters *posters = Posters::instance();
    for (auto it = resolved.cbegin(); it != resolved.cend(); ++it)
    {
        const FilmInfo &film = it.value();
        if (film.key != it.key())
            posters->alias(it.key(), film.key);
        m_resolved.insert(it.key(), film);
    }
    for (auto it = nameKeys.cbegin(); it != nameKeys.cend(); ++it)
    {
        if (!m_resolved.contains(it.key()))
            posters->alias(it.key(), m_resolved.value(it.value()).key);
    }

    // the films the query names: by the titles of at least one of their releases (a release of one named
    // only in Russian goes with the rest of its film)
    QSet<QString> named;
    for (int i = 0; i < results->rowCount(); ++i)
    {
        const SearchRow *r = results->rowAt(i);
        if (r && titlesMatch(r->name, r->meta, m_query))
            named.insert(filmOf(*r).key);
    }
    const bool namedChanged = (named != m_namedFilms);
    m_namedFilms = named;

    for (const FilmInfo &film : std::as_const(m_resolved))
    {
        // (a film left out needs no poster while it is)
        if (m_exact && !m_namedFilms.contains(film.key))
            continue;
        if (!posters->hasAlias(film.key))
            posters->request(film.key, film.title, film.original, film.year, film.series);
    }
    if (namedChanged && m_exact)
        invalidateFilter();
}

bool SearchResultsFilter::matchesQuery(const SearchRow &row) const
{
    return titlesMatch(row.name, row.meta, m_query) || m_namedFilms.contains(filmOf(row).key);
}

FilmInfo SearchResultsFilter::filmOfRelease(const QString &name, const ReleaseMeta &meta)
{
    FilmInfo film = FilmInfo::parse(name);
    static const QRegularExpression latin {u"[A-Za-z]"_s};
    static const QRegularExpression cyrillic {u"[\\x{0400}-\\x{04FF}]"_s};
    QString local = plausibleTitle(meta.title) ? meta.title : QString();
    QString original = plausibleTitle(meta.original) ? meta.original : QString();
    // and now and then the other way round
    if (local.contains(latin) && !local.contains(cyrillic) && original.contains(cyrillic))
        std::swap(local, original);
    if (!local.isEmpty())
        film.title = local;
    if (original.contains(latin) && !original.contains(cyrillic))
        film.original = original;
    else if (film.original.isEmpty() && local.contains(latin) && !local.contains(cyrillic))
        film.original = local;
    if (meta.year > 0)
        film.year = meta.year;
    if (!meta.seasons.isEmpty())
        film.series = true;
    film.key = FilmInfo::keyOf(film.title, film.original, film.year);
    return film;
}

FilmInfo SearchResultsFilter::filmOf(const SearchRow &row) const
{
    FilmInfo film = filmOfRelease(row.name, row.meta);
    if (const auto it = m_resolved.constFind(film.key); it != m_resolved.cend())
    {
        film.key = it->key;
        film.original = it->original;
        film.year = it->year;
    }
    return film;
}

QVariantList SearchResultsFilter::groups() const
{
    return m_groups;
}

void SearchResultsFilter::regroup()
{
    resolveFilms();
    countLoose();

    const auto *results = qobject_cast<const SearchResultsModel *>(sourceModel());
    QList<QVariantMap> groups;
    QHash<QString, qsizetype> indexOf;
    static const QStringList qualityOrder {u"2160p"_s, u"1080p"_s, u"720p"_s, u"576p"_s, u"480p"_s};

    struct Parsed
    {
        int source;
        const SearchRow *row;
        FilmInfo film;
    };
    QList<Parsed> parsed;
    QHash<QString, QHash<QString, int>> voiceCounts;  // film → voice-over → releases with it
    for (int i = 0; results && (i < rowCount()); ++i)
    {
        const int source = mapToSource(index(i, 0)).row();
        const SearchRow *r = results->rowAt(source);
        if (r)
            parsed.append({source, r, filmOf(*r)});
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
            group.insert(u"voices"_s, QStringList {});
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
        const QStringList studios = studiosOf(r->meta.voices);
        QVariantList releases = group.value(u"releases"_s).toList();
        releases.append(QVariantMap {
            {u"row"_s, source}, {u"name"_s, r->name}, {u"size"_s, r->size}, {u"seeds"_s, r->seeds},
            {u"leechers"_s, r->leechers}, {u"engine"_s, r->engine}, {u"fileUrl"_s, r->fileUrl},
            {u"published"_s, r->published}, {u"downloaded"_s, r->downloaded}, {u"quality"_s, film.quality},
            {u"voices"_s, studios}, {u"tags"_s, tagsOf(r->name, r->meta)}
        });
        group[u"releases"_s] = releases;
        for (const QString &voice : studios)
            ++voiceCounts[film.key][voice];
    }

    // a film's voice-overs, the most common first
    for (QVariantMap &group : groups)
    {
        const QHash<QString, int> counts = voiceCounts.value(group.value(u"key"_s).toString());
        QStringList voices = counts.keys();
        std::sort(voices.begin(), voices.end(), [&counts](const QString &a, const QString &b)
        {
            const int ca = counts.value(a);
            const int cb = counts.value(b);
            return (ca != cb) ? (ca > cb) : (a.compare(b, Qt::CaseInsensitive) < 0);
        });
        group[u"voices"_s] = voices;
    }

    m_groups.clear();
    m_fullGroups.clear();
    for (const QVariantMap &group : std::as_const(groups))
    {
        m_fullGroups.insert(group.value(u"key"_s).toString(), group);
        QVariantMap card = group;
        card.remove(u"releases"_s);
        m_groups.append(card);
    }
    emit groupsChanged();
}

QVariantMap SearchResultsFilter::group(const QString &key) const
{
    return m_fullGroups.value(key);
}

QString SearchResultsFilter::query() const
{
    return m_query;
}

void SearchResultsFilter::setQuery(const QString &query)
{
    if (query == m_query)
        return;
    m_query = query;
    invalidateFilter();
    countLoose();
    emit filterChanged();
}

bool SearchResultsFilter::exact() const
{
    return m_exact;
}

void SearchResultsFilter::setExact(const bool exact)
{
    if (exact == m_exact)
        return;
    m_exact = exact;
    invalidateFilter();
    emit filterChanged();
}

int SearchResultsFilter::looseCount() const
{
    return m_looseCount;
}

void SearchResultsFilter::countLoose()
{
    const auto *results = qobject_cast<const SearchResultsModel *>(sourceModel());
    int loose = 0;
    for (int i = 0; results && (i < results->rowCount()); ++i)
    {
        const SearchRow *r = results->rowAt(i);
        if (r && !matchesQuery(*r))
            ++loose;
    }
    if (loose == m_looseCount)
        return;
    m_looseCount = loose;
    emit looseCountChanged();
}

bool SearchResultsFilter::titlesMatch(const QString &name, const ReleaseMeta &meta, const QString &query)
{
    static const QRegularExpression separators {u"[^\\p{L}\\p{N}]+"_s, QRegularExpression::UseUnicodePropertiesOption};
    const auto wordsOf = [](const QString &text)
    {
        QString t = text.toCaseFolded();
        t.replace(u'ё', u'е');
        return t.split(separators, Qt::SkipEmptyParts);
    };

    // the words that say what is looked for: of three letters or more (not "по", "2", "s01")
    QStringList wanted;
    for (const QString &word : wordsOf(query))
    {
        static const QRegularExpression letters {u"\\p{L}"_s, QRegularExpression::UseUnicodePropertiesOption};
        if ((word.size() >= 3) && word.contains(letters))
            wanted.append(word);
    }
    if (wanted.isEmpty())
        return true;

    // the titles: what the source knows, and the name up to its first bracket (the genres, the year and the
    // notes are in brackets: "Эксперименты Лэйн / Serial Experiments Lain [1998, …, киберпанк, …]")
    QString head = name;
    if (const qsizetype bracket = head.indexOf(u'['); bracket > 0)
        head.truncate(bracket);
    const QString known = (plausibleTitle(meta.title) ? meta.title : QString()) + u' '
        + (plausibleTitle(meta.original) ? meta.original : QString());
    const QStringList titleWords = wordsOf(known + u' ' + head);

    int found = 0;
    for (const QString &word : std::as_const(wanted))
    {
        // the stem: a word's ending changes with its case ("киберпанка", "бегущих")
        const QString stem = (word.size() >= 5) ? word.left(std::max<qsizetype>(4, word.size() - 2)) : word;
        // (inside a word too: "ubuntu" in "Kubuntu", "stellar" in "Interstellar")
        const bool has = std::any_of(titleWords.cbegin(), titleWords.cend(), [&stem](const QString &w)
        {
            return w.startsWith(stem) || ((stem.size() >= 4) && w.contains(stem));
        });
        if (has)
            ++found;
    }
    // most of the words: a title spelled a little differently ("Бегушие") still counts
    return (found * 2) >= wanted.size() && (found > 0);
}

QVariantList SearchResultsFilter::tagsOf(const QString &name, const ReleaseMeta &meta)
{
    QVariantList tags;
    const auto add = [&tags](const QString &kind, const QString &text)
    {
        tags.append(QVariantMap {{u"kind"_s, kind}, {u"text"_s, text}});
    };
    const auto first = [&name](const QList<std::pair<QRegularExpression, QString>> &table) -> QString
    {
        for (const auto &[pattern, text] : table)
        {
            if (name.contains(pattern))
                return text;
        }
        return {};
    };
    const auto re = [](const char16_t *pattern)
    {
        return QRegularExpression(QString::fromUtf16(pattern), QRegularExpression::CaseInsensitiveOption
            | QRegularExpression::UseUnicodePropertiesOption);
    };

    if (const QString quality = FilmInfo::parse(name).quality; !quality.isEmpty())
        add(u"quality"_s, (quality == u"2160p") ? u"4K"_s : quality);

    static const QList<std::pair<QRegularExpression, QString>> hdr {
        {re(u"dolby\\s*vision|\\bDV\\b|\\bDoVi\\b"), u"Dolby Vision"_s},
        {re(u"\\bHDR(10\\+?)?\\b"), u"HDR"_s}
    };
    QString video = first(hdr);
    if (meta.video == u"dv")
        video = u"Dolby Vision"_s;
    else if ((meta.video == u"hdr") && video.isEmpty())
        video = u"HDR"_s;
    if (!video.isEmpty())
        add(u"hdr"_s, video);

    static const QList<std::pair<QRegularExpression, QString>> sources {
        {re(u"\\bremux\\b"), u"Remux"_s},
        {re(u"\\bWEB[- ]?DLRip\\b"), u"WEB-DLRip"_s},
        {re(u"\\bWEB[- ]?DL\\b"), u"WEB-DL"_s},
        {re(u"\\bWEB[- ]?Rip\\b|\\bWeb\\b"), u"WEBRip"_s},
        {re(u"\\bBD[- ]?Rip\\b|\\bBR[- ]?Rip\\b"), u"BDRip"_s},
        {re(u"\\bBlu[- ]?Ray\\b|\\bBDMV\\b|\\bBD\\d{2}\\b"), u"Blu-ray"_s},
        {re(u"\\bHDTV(Rip)?\\b"), u"HDTV"_s},
        {re(u"\\bDVD(Rip|5|9)?\\b"), u"DVD"_s},
        {re(u"\\b(SAT|TV)Rip\\b"), u"TVRip"_s},
        {re(u"\\bCAM(Rip)?\\b|\\bTS\\b|\\bTelesync\\b"), u"CAM"_s}
    };
    if (const QString source = first(sources); !source.isEmpty())
        add(u"source"_s, source);

    static const QList<std::pair<QRegularExpression, QString>> codecs {
        {re(u"\\bHEVC\\b|\\bx\\.?265\\b|\\bH\\.?265\\b"), u"HEVC"_s},
        {re(u"\\bAV1\\b"), u"AV1"_s}
    };
    if (const QString codec = first(codecs); !codec.isEmpty())
        add(u"codec"_s, codec);

    // seasons: what the source knows, else the name ("Сезон: 2", "2 сезон", "S02", "Season 2")
    QList<int> seasons = meta.seasons;
    if (seasons.isEmpty())
    {
        static const QRegularExpression seasonRe = re(u"(?:сезон[:\\s]*|season\\s*|\\bS)(\\d{1,2})(?![\\d])|(\\d{1,2})\\s*-?\\s*(?:й\\s*)?сезон");
        for (auto it = seasonRe.globalMatch(name); it.hasNext();)
        {
            const QRegularExpressionMatch m = it.next();
            const int n = (m.captured(1).isEmpty() ? m.captured(2) : m.captured(1)).toInt();
            if ((n > 0) && !seasons.contains(n))
                seasons.append(n);
        }
    }
    if (!seasons.isEmpty())
    {
        std::sort(seasons.begin(), seasons.end());
        const bool run = (seasons.size() > 2) && ((seasons.last() - seasons.first()) == (seasons.size() - 1));
        QStringList texts;
        for (const int n : std::as_const(seasons))
            texts.append(QString::number(n));
        add(u"season"_s, run ? (texts.first() + u'–' + texts.last()) : texts.join(u", "_s));
    }

    // episodes: "Серии: 1-10 из 10", "10 из 10", "[+10 серия]"
    static const QRegularExpression episodesRe = re(u"(?:серии|эпизоды|episodes?)[:\\s]*(\\d{1,4})\\s*[-–]\\s*(\\d{1,4})(?:\\s*(?:из|of)\\s*(\\d{1,4}))?"
                                                    "|(\\d{1,4})\\s*(?:из|of)\\s*(\\d{1,4})");
    if (const QRegularExpressionMatch m = episodesRe.match(name); m.hasMatch())
    {
        if (!m.captured(1).isEmpty())
            add(u"episodes"_s, m.captured(1) + u'–' + m.captured(2) + (m.captured(3).isEmpty() ? QString() : (u'/' + m.captured(3))));
        else
            add(u"episodes"_s, m.captured(4) + u'/' + m.captured(5));
    }

    // the kinds of voice-over: words, and rutor's letters ("| D, P, L |": dubbing, professional, amateur)
    static const QList<std::pair<QRegularExpression, QString>> audio {
        {re(u"\\bdub\\b|дубл|\\bdubbed\\b"), u"dub"_s},
        // ("2 x MVO", "2xMVO")
        {re(u"\\b(\\d\\s*)?x?MVO\\b|многоголос"), u"mvo"_s},
        {re(u"\\b(\\d\\s*)?x?DVO\\b|двухголос"), u"dvo"_s},
        {re(u"\\b(\\d\\s*)?x?AVO\\b|авторск|одноголос|\\bVO\\b"), u"avo"_s},
        {re(u"\\bsubs?\\b|субтитр"), u"sub"_s},
        {re(u"\\boriginal\\b|оригинал|\\braw\\b"), u"original"_s}
    };
    QStringList kinds;
    for (const auto &[pattern, kind] : audio)
    {
        if (name.contains(pattern))
            kinds.append(kind);
    }
    static const QRegularExpression letters {u"\\|\\s*([DPLA](?:\\s*,\\s*[DPLA])*)\\s*(?:\\||$)"_s};
    if (const QRegularExpressionMatch m = letters.match(name); m.hasMatch())
    {
        for (const QString &letter : m.captured(1).split(u',', Qt::SkipEmptyParts))
        {
            const QString t = letter.trimmed();
            const QString kind = (t == u"D") ? u"dub"_s : (t == u"P") ? u"pro"_s : (t == u"L") ? u"amateur"_s : u"avo"_s;
            if (!kinds.contains(kind))
                kinds.append(kind);
        }
    }
    // a source's voice-over that is a kind, not a studio ("Дубляж")
    for (const QString &voice : meta.voices)
    {
        if (const QString kind = voiceKind(voice); !kind.isEmpty() && !kinds.contains(kind))
            kinds.append(kind);
    }
    for (const QString &kind : std::as_const(kinds))
        add(u"audio"_s, kind);
    return tags;
}

QString SearchResultsFilter::voiceKind(const QString &voice)
{
    static const QList<std::pair<QRegularExpression, QString>> kinds {
        {QRegularExpression(u"^(дубл|dub)"_s, QRegularExpression::CaseInsensitiveOption), u"dub"_s},
        {QRegularExpression(u"^(многоголос|mvo)"_s, QRegularExpression::CaseInsensitiveOption), u"mvo"_s},
        {QRegularExpression(u"^(двухголос|dvo)"_s, QRegularExpression::CaseInsensitiveOption), u"dvo"_s},
        {QRegularExpression(u"^(одноголос|авторск|avo)"_s, QRegularExpression::CaseInsensitiveOption), u"avo"_s},
        {QRegularExpression(u"^(профессиональн)"_s, QRegularExpression::CaseInsensitiveOption), u"pro"_s},
        {QRegularExpression(u"^(любительск)"_s, QRegularExpression::CaseInsensitiveOption), u"amateur"_s},
        {QRegularExpression(u"^(субтитр|sub)"_s, QRegularExpression::CaseInsensitiveOption), u"sub"_s},
        {QRegularExpression(u"^(оригинал|original)"_s, QRegularExpression::CaseInsensitiveOption), u"original"_s}
    };
    const QString v = voice.trimmed();
    for (const auto &[pattern, kind] : kinds)
    {
        if (v.contains(pattern))
            return kind;
    }
    return {};
}

QStringList SearchResultsFilter::studiosOf(const QStringList &voices)
{
    QStringList studios;
    for (const QString &voice : voices)
    {
        if (voiceKind(voice).isEmpty())
            studios.append(voice);
    }
    return studios;
}
