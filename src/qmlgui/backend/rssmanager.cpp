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

#include "rssmanager.h"

#include <functional>

#include <QCoreApplication>
#include <QDesktopServices>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QTextDocumentFragment>
#include <QUrl>

#include "base/addtorrentmanager.h"
#include "base/bittorrent/addtorrentparams.h"
#include "base/global.h"
#include "base/interfaces/iapplication.h"
#include "base/path.h"
#include "base/rss/rss_article.h"
#include "base/rss/rss_autodownloader.h"
#include "base/rss/rss_autodownloadrule.h"
#include "base/rss/rss_feed.h"
#include "base/rss/rss_folder.h"
#include "base/rss/rss_session.h"

namespace
{
    // Plain text of an HTML description, collapsed to one line, for the list snippet
    QString snippetOf(const QString &description)
    {
        QString text = description.contains(u'<') ? QTextDocumentFragment::fromHtml(description).toPlainText() : description;
        static const QRegularExpression spaces {u"\\s+"_s};
        text.replace(spaces, u" "_s);
        return text.trimmed().left(220);
    }

    bool addTorrentSource(const QString &source)
    {
        auto *app = dynamic_cast<IApplication *>(QCoreApplication::instance());
        return app && app->addTorrentManager() && app->addTorrentManager()->addTorrent(source);
    }

    QVariantMap ruleToMap(const RSS::AutoDownloadRule &rule)
    {
        const BitTorrent::AddTorrentParams params = rule.addTorrentParams();
        return {
            {u"name"_s, rule.name()},
            {u"enabled"_s, rule.isEnabled()},
            {u"mustContain"_s, rule.mustContain()},
            {u"mustNotContain"_s, rule.mustNotContain()},
            {u"useRegex"_s, rule.useRegex()},
            {u"smartFilter"_s, rule.useSmartFilter()},
            {u"episodeFilter"_s, rule.episodeFilter()},
            {u"ignoreDays"_s, rule.ignoreDays()},
            {u"feeds"_s, rule.feedURLs()},
            {u"category"_s, params.category},
            {u"savePath"_s, params.savePath.toString()},
            {u"lastMatch"_s, rule.lastMatch()}
        };
    }

    void applyMapToRule(const QVariantMap &map, RSS::AutoDownloadRule &rule)
    {
        rule.setEnabled(map.value(u"enabled"_s, true).toBool());
        rule.setMustContain(map.value(u"mustContain"_s).toString());
        rule.setMustNotContain(map.value(u"mustNotContain"_s).toString());
        rule.setUseRegex(map.value(u"useRegex"_s).toBool());
        rule.setUseSmartFilter(map.value(u"smartFilter"_s).toBool());
        rule.setEpisodeFilter(map.value(u"episodeFilter"_s).toString());
        rule.setIgnoreDays(map.value(u"ignoreDays"_s).toInt());
        rule.setFeedURLs(map.value(u"feeds"_s).toStringList());
        BitTorrent::AddTorrentParams params = rule.addTorrentParams();
        params.category = map.value(u"category"_s).toString();
        params.savePath = Path(map.value(u"savePath"_s).toString());
        rule.setAddTorrentParams(params);
    }
}

// --- RssArticlesModel ---------------------------------------------------------------------------

RssArticlesModel::RssArticlesModel(QObject *parent)
    : QAbstractListModel(parent)
{
    connect(this, &QAbstractItemModel::modelReset, this, &RssArticlesModel::countChanged);
}

int RssArticlesModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : static_cast<int>(m_rows.size());
}

QVariant RssArticlesModel::data(const QModelIndex &index, const int role) const
{
    if (!index.isValid() || (index.row() >= m_rows.size()))
        return {};

    const RssArticleRow &r = m_rows.at(index.row());
    switch (role)
    {
    case Qt::DisplayRole:
    case TitleRole: return r.title;
    case GuidRole: return r.guid;
    case FeedNameRole: return r.feedName;
    case AuthorRole: return r.author;
    case DescriptionRole: return r.description;
    case SnippetRole: return snippetOf(r.description);
    case TorrentUrlRole: return r.torrentUrl;
    case LinkRole: return r.link;
    case DateRole: return r.date;
    case ReadRole: return r.read;
    default: return {};
    }
}

QHash<int, QByteArray> RssArticlesModel::roleNames() const
{
    return {
        {GuidRole, "guid"},
        {FeedNameRole, "feedName"},
        {TitleRole, "title"},
        {AuthorRole, "author"},
        {DescriptionRole, "description"},
        {SnippetRole, "snippet"},
        {TorrentUrlRole, "torrentUrl"},
        {LinkRole, "link"},
        {DateRole, "date"},
        {ReadRole, "read"}
    };
}

void RssArticlesModel::setRows(QList<RssArticleRow> rows)
{
    beginResetModel();
    m_rows = std::move(rows);
    endResetModel();
}

const RssArticleRow *RssArticlesModel::rowAt(const int i) const
{
    return ((i >= 0) && (i < m_rows.size())) ? &m_rows.at(i) : nullptr;
}

void RssArticlesModel::setRead(const int i)
{
    if ((i < 0) || (i >= m_rows.size()) || m_rows.at(i).read)
        return;

    m_rows[i].read = true;
    emit dataChanged(index(i), index(i), {ReadRole});
}

// --- RssManager ---------------------------------------------------------------------------------

RssManager::RssManager(QObject *parent)
    : QObject(parent)
    , m_articles {new RssArticlesModel(this)}
{
    m_articlesTimer.setSingleShot(true);
    m_articlesTimer.setInterval(60);
    connect(&m_articlesTimer, &QTimer::timeout, this, &RssManager::rebuildArticles);
    m_feedsTimer.setSingleShot(true);
    m_feedsTimer.setInterval(60);
    connect(&m_feedsTimer, &QTimer::timeout, this, &RssManager::rebuildFeeds);

    // Development aid for window captures
    if (const QString demo = qEnvironmentVariable("FLUX_DEMO_RSS"); !demo.isEmpty())
    {
        QFile file {demo};
        if (file.open(QIODevice::ReadOnly))
        {
            loadDemo(QJsonDocument::fromJson(file.readAll()).object().toVariantMap());
            return;
        }
    }

    attach();
}

RssManager *RssManager::create(QQmlEngine *, QJSEngine *)
{
    return new RssManager;
}

void RssManager::attach()
{
    auto *session = RSS::Session::instance();
    if (!session)
        return;

    const auto feedsDirty = [this] { m_feedsTimer.start(); };
    connect(session, &RSS::Session::itemAdded, this, feedsDirty);
    connect(session, &RSS::Session::itemPathChanged, this, feedsDirty);
    connect(session, &RSS::Session::itemAboutToBeRemoved, this, [this](RSS::Item *item)
    {
        if ((item->path() == m_selectedPath) || m_selectedPath.startsWith(item->path() + RSS::Item::PathSeparator))
            setSelectedPath({});
        m_feedsTimer.start();
        scheduleArticles();
    });
    connect(session, &RSS::Session::feedStateChanged, this, feedsDirty);
    connect(session, &RSS::Session::processingStateChanged, this, &RssManager::settingsChanged);

    RSS::Folder *root = session->rootFolder();
    connect(root, &RSS::Item::unreadCountChanged, this, feedsDirty);
    connect(root, &RSS::Item::newArticle, this, &RssManager::scheduleArticles);
    connect(root, &RSS::Item::articleAboutToBeRemoved, this, &RssManager::scheduleArticles);
    connect(root, &RSS::Item::articleRead, this, [this]
    {
        m_feedsTimer.start();
        if (m_unreadOnly)
            scheduleArticles();
    });

    if (auto *downloader = RSS::AutoDownloader::instance())
    {
        connect(downloader, &RSS::AutoDownloader::processingStateChanged, this, &RssManager::settingsChanged);
        connect(downloader, &RSS::AutoDownloader::ruleAdded, this, &RssManager::rebuildRules);
        connect(downloader, &RSS::AutoDownloader::ruleChanged, this, &RssManager::rebuildRules);
        connect(downloader, &RSS::AutoDownloader::ruleRenamed, this, &RssManager::rebuildRules);
        connect(downloader, &RSS::AutoDownloader::ruleAboutToBeRemoved, this, [this] { QTimer::singleShot(0, this, &RssManager::rebuildRules); });
    }

    rebuildFeeds();
    rebuildArticles();
    rebuildRules();
}

bool RssManager::processingEnabled() const
{
    if (m_demo)
        return m_demoProcessing;
    const auto *session = RSS::Session::instance();
    return session && session->isProcessingEnabled();
}

void RssManager::setProcessingEnabled(const bool enabled)
{
    if (m_demo)
    {
        m_demoProcessing = enabled;
        emit settingsChanged();
        return;
    }
    if (auto *session = RSS::Session::instance())
        session->setProcessingEnabled(enabled);
}

bool RssManager::autoDownloadEnabled() const
{
    if (m_demo)
        return m_demoAutoDownload;
    const auto *downloader = RSS::AutoDownloader::instance();
    return downloader && downloader->isProcessingEnabled();
}

void RssManager::setAutoDownloadEnabled(const bool enabled)
{
    if (m_demo)
    {
        m_demoAutoDownload = enabled;
        emit settingsChanged();
        return;
    }
    if (auto *downloader = RSS::AutoDownloader::instance())
        downloader->setProcessingEnabled(enabled);
}

int RssManager::refreshInterval() const
{
    if (m_demo)
        return m_demoInterval;
    const auto *session = RSS::Session::instance();
    return session ? session->refreshInterval() : 30;
}

void RssManager::setRefreshInterval(const int minutes)
{
    if (minutes < 1)
        return;
    if (m_demo)
        m_demoInterval = minutes;
    else if (auto *session = RSS::Session::instance())
        session->setRefreshInterval(minutes);
    emit settingsChanged();
}

QVariantList RssManager::feeds() const
{
    return m_feeds;
}

int RssManager::unreadCount() const
{
    return m_unread;
}

QString RssManager::selectedPath() const
{
    return m_selectedPath;
}

void RssManager::setSelectedPath(const QString &path)
{
    if (path == m_selectedPath)
        return;

    m_selectedPath = path;
    emit selectionChanged();
    rebuildArticles();
}

QString RssManager::search() const
{
    return m_search;
}

void RssManager::setSearch(const QString &search)
{
    if (search == m_search)
        return;

    m_search = search;
    emit selectionChanged();
    scheduleArticles();
}

bool RssManager::unreadOnly() const
{
    return m_unreadOnly;
}

void RssManager::setUnreadOnly(const bool on)
{
    if (on == m_unreadOnly)
        return;

    m_unreadOnly = on;
    emit selectionChanged();
    rebuildArticles();
}

RssArticlesModel *RssManager::articles() const
{
    return m_articles;
}

QVariantList RssManager::rules() const
{
    return m_rules;
}

void RssManager::scheduleArticles()
{
    m_articlesTimer.start();
}

void RssManager::rebuildFeeds()
{
    if (m_demo)
        return;

    const auto *session = RSS::Session::instance();
    if (!session)
        return;

    QVariantList list;
    const std::function<void (const RSS::Folder *, int)> walk = [&](const RSS::Folder *folder, const int depth)
    {
        QList<RSS::Item *> items = folder->items();
        std::sort(items.begin(), items.end(), [](const RSS::Item *a, const RSS::Item *b)
        {
            const bool af = qobject_cast<const RSS::Folder *>(a) != nullptr;
            const bool bf = qobject_cast<const RSS::Folder *>(b) != nullptr;
            if (af != bf)
                return af; // folders first
            return a->name().compare(b->name(), Qt::CaseInsensitive) < 0;
        });
        for (const RSS::Item *item : std::as_const(items))
        {
            QVariantMap entry {
                {u"path"_s, item->path()},
                {u"name"_s, item->name()},
                {u"depth"_s, depth},
                {u"unread"_s, item->unreadCount()},
                {u"total"_s, item->articles().size()}
            };
            if (const auto *sub = qobject_cast<const RSS::Folder *>(item))
            {
                entry.insert(u"folder"_s, true);
                list.append(entry);
                walk(sub, depth + 1);
            }
            else if (const auto *feed = qobject_cast<const RSS::Feed *>(item))
            {
                entry.insert(u"folder"_s, false);
                entry.insert(u"url"_s, feed->url());
                entry.insert(u"loading"_s, feed->isLoading());
                entry.insert(u"error"_s, feed->hasError());
                list.append(entry);
            }
        }
    };
    walk(session->rootFolder(), 0);

    m_feeds = list;
    m_unread = session->rootFolder()->unreadCount();
    emit feedsChanged();
}

QList<RssArticleRow> RssManager::collectArticles() const
{
    QList<RssArticleRow> rows;
    if (m_demo)
    {
        for (auto it = m_demoArticles.cbegin(); it != m_demoArticles.cend(); ++it)
        {
            const QString &feedPath = it.key();
            if (m_selectedPath.isEmpty() || (feedPath == m_selectedPath)
                || feedPath.startsWith(m_selectedPath + RSS::Item::PathSeparator))
                rows.append(it.value());
        }
    }
    else if (const auto *session = RSS::Session::instance())
    {
        const RSS::Item *item = m_selectedPath.isEmpty() ? session->rootFolder() : session->itemByPath(m_selectedPath);
        if (item)
        {
            for (RSS::Article *article : item->articles())
            {
                RssArticleRow row;
                row.guid = article->guid();
                row.feedUrl = article->feed()->url();
                row.feedName = article->feed()->name();
                row.title = article->title();
                row.author = article->author();
                row.description = article->description();
                row.torrentUrl = article->torrentUrl();
                row.link = article->link();
                row.date = article->date();
                row.read = article->isRead();
                row.article = article;
                rows.append(row);
            }
        }
    }

    const QStringList words = m_search.split(u' ', Qt::SkipEmptyParts);
    rows.removeIf([&](const RssArticleRow &r)
    {
        if (m_unreadOnly && r.read)
            return true;
        for (const QString &word : words)
        {
            if (!r.title.contains(word, Qt::CaseInsensitive))
                return true;
        }
        return false;
    });
    std::stable_sort(rows.begin(), rows.end(), [](const RssArticleRow &a, const RssArticleRow &b)
    {
        return a.date > b.date;
    });
    return rows;
}

void RssManager::rebuildArticles()
{
    m_articles->setRows(collectArticles());
}

void RssManager::rebuildRules()
{
    if (m_demo)
        return;

    QVariantList list;
    if (const auto *downloader = RSS::AutoDownloader::instance())
    {
        for (const RSS::AutoDownloadRule &rule : downloader->rules())
            list.append(ruleToMap(rule));
    }
    m_rules = list;
    emit rulesChanged();
}

QString RssManager::addFeed(const QString &url, const QString &folderPath)
{
    const QString link = url.trimmed();
    if (link.isEmpty())
        return tr("Enter the feed address.");
    if (m_demo)
        return {};

    auto *session = RSS::Session::instance();
    if (!session)
        return tr("RSS is not available.");
    // The feed is named after its URL until its first fetch brings the title
    const auto result = session->addFeed(link, RSS::Item::joinPath(folderPath, link));
    return result ? QString() : result.error();
}

QString RssManager::addFolder(const QString &name)
{
    if (name.trimmed().isEmpty())
        return tr("Enter a folder name.");
    if (m_demo)
        return {};

    auto *session = RSS::Session::instance();
    if (!session)
        return tr("RSS is not available.");
    const auto result = session->addFolder(name.trimmed());
    return result ? QString() : result.error();
}

QString RssManager::rename(const QString &path, const QString &newName)
{
    if (newName.trimmed().isEmpty())
        return tr("Enter a name.");
    if (m_demo)
        return {};

    auto *session = RSS::Session::instance();
    if (!session)
        return tr("RSS is not available.");
    const QString dest = RSS::Item::joinPath(RSS::Item::parentPath(path), newName.trimmed());
    const auto result = session->moveItem(path, dest);
    if (!result)
        return result.error();
    if (m_selectedPath == path)
        setSelectedPath(dest);
    return {};
}

QString RssManager::remove(const QString &path)
{
    if (m_demo)
        return {};

    auto *session = RSS::Session::instance();
    if (!session)
        return tr("RSS is not available.");
    const auto result = session->removeItem(path);
    return result ? QString() : result.error();
}

void RssManager::refresh(const QString &path)
{
    if (const auto *session = RSS::Session::instance(); session && !m_demo)
    {
        RSS::Item *item = path.isEmpty() ? session->rootFolder() : session->itemByPath(path);
        if (item)
            item->refresh();
    }
}

void RssManager::markAllRead(const QString &path)
{
    if (m_demo)
    {
        for (auto it = m_demoArticles.begin(); it != m_demoArticles.end(); ++it)
        {
            if (path.isEmpty() || (it.key() == path) || it.key().startsWith(path + RSS::Item::PathSeparator))
            {
                for (RssArticleRow &row : it.value())
                    row.read = true;
            }
        }
        rebuildArticles();
        return;
    }

    if (const auto *session = RSS::Session::instance())
    {
        RSS::Item *item = path.isEmpty() ? session->rootFolder() : session->itemByPath(path);
        if (item)
            item->markAsRead();
        rebuildArticles();
    }
}

void RssManager::markRead(const int row)
{
    const RssArticleRow *r = m_articles->rowAt(row);
    if (!r || r->read)
        return;

    if (r->article)
        r->article->markAsRead();
    m_articles->setRead(row);
}

bool RssManager::download(const int row)
{
    const RssArticleRow *r = m_articles->rowAt(row);
    if (!r)
        return false;

    const QString source = !r->torrentUrl.isEmpty() ? r->torrentUrl
        : RSS::Article::isSupportedTorrentURL(r->link) ? r->link : QString();
    if (source.isEmpty())
        return false;

    markRead(row);
    return m_demo || addTorrentSource(source);
}

void RssManager::openLink(const int row)
{
    const RssArticleRow *r = m_articles->rowAt(row);
    if (!r)
        return;

    const QUrl url {r->link};
    if (url.isValid() && url.scheme().startsWith(u"http"))
        QDesktopServices::openUrl(url);
    markRead(row);
}

QString RssManager::saveRule(const QVariantMap &rule, const QString &oldName)
{
    const QString name = rule.value(u"name"_s).toString().trimmed();
    if (name.isEmpty())
        return tr("Enter a rule name.");

    if (m_demo)
    {
        QVariantMap stored = rule;
        stored.insert(u"name"_s, name);
        for (qsizetype i = 0; i < m_rules.size(); ++i)
        {
            const QString existing = m_rules.at(i).toMap().value(u"name"_s).toString();
            if ((existing == name) && (existing != oldName))
                return tr("A rule with this name already exists.");
        }
        for (qsizetype i = 0; i < m_rules.size(); ++i)
        {
            if (!oldName.isEmpty() && (m_rules.at(i).toMap().value(u"name"_s).toString() == oldName))
            {
                m_rules[i] = stored;
                emit rulesChanged();
                return {};
            }
        }
        m_rules.append(stored);
        emit rulesChanged();
        return {};
    }

    auto *downloader = RSS::AutoDownloader::instance();
    if (!downloader)
        return tr("RSS is not available.");

    if (oldName.isEmpty() || (oldName != name))
    {
        if (downloader->hasRule(name))
            return tr("A rule with this name already exists.");
        if (!oldName.isEmpty() && !downloader->renameRule(oldName, name))
            return tr("Could not rename the rule.");
    }

    RSS::AutoDownloadRule stored = downloader->hasRule(name) ? downloader->ruleByName(name) : RSS::AutoDownloadRule(name);
    applyMapToRule(rule, stored);
    downloader->setRule(stored);
    return {};
}

void RssManager::removeRule(const QString &name)
{
    if (m_demo)
    {
        for (qsizetype i = 0; i < m_rules.size(); ++i)
        {
            if (m_rules.at(i).toMap().value(u"name"_s).toString() == name)
            {
                m_rules.removeAt(i);
                emit rulesChanged();
                return;
            }
        }
        return;
    }

    if (auto *downloader = RSS::AutoDownloader::instance())
        downloader->removeRule(name);
}

QStringList RssManager::previewRule(const QVariantMap &map) const
{
    RSS::AutoDownloadRule rule {u"preview"_s};
    applyMapToRule(map, rule);
    rule.setEnabled(true);
    const QStringList feeds = rule.feedURLs();

    QStringList titles;
    const auto consider = [&](const QVariantHash &data, const QString &title)
    {
        if ((titles.size() < 50) && rule.matches(data))
            titles.append(title);
    };

    if (m_demo)
    {
        for (const QList<RssArticleRow> &rows : m_demoArticles)
        {
            for (const RssArticleRow &r : rows)
            {
                if (!feeds.contains(r.feedUrl))
                    continue;
                consider({{RSS::Article::KeyTitle, r.title}, {RSS::Article::KeyDate, r.date}}, r.title);
            }
        }
        return titles;
    }

    const auto *session = RSS::Session::instance();
    if (!session)
        return titles;
    for (const QString &url : feeds)
    {
        if (const RSS::Feed *feed = session->feedByURL(url))
        {
            for (const RSS::Article *article : feed->articles())
                consider(article->data(), article->title());
        }
    }
    return titles;
}

void RssManager::loadDemo(const QVariantMap &state)
{
    m_demo = true;
    m_demoProcessing = state.value(u"processing"_s, true).toBool();
    m_demoAutoDownload = state.value(u"autoDownload"_s, true).toBool();
    m_demoInterval = state.value(u"interval"_s, 30).toInt();
    m_feeds = state.value(u"feeds"_s).toList();
    m_rules = state.value(u"rules"_s).toList();

    QHash<QString, QString> urlByPath;
    QHash<QString, QString> nameByPath;
    for (const QVariant &f : std::as_const(m_feeds))
    {
        const QVariantMap feed = f.toMap();
        urlByPath.insert(feed.value(u"path"_s).toString(), feed.value(u"url"_s).toString());
        nameByPath.insert(feed.value(u"path"_s).toString(), feed.value(u"name"_s).toString());
    }

    m_demoArticles.clear();
    m_unread = 0;
    const QVariantMap articles = state.value(u"articles"_s).toMap();
    for (auto it = articles.cbegin(); it != articles.cend(); ++it)
    {
        QList<RssArticleRow> rows;
        for (const QVariant &a : it.value().toList())
        {
            const QVariantMap map = a.toMap();
            RssArticleRow row;
            row.guid = map.value(u"guid"_s, map.value(u"title"_s)).toString();
            row.feedUrl = urlByPath.value(it.key());
            row.feedName = nameByPath.value(it.key());
            row.title = map.value(u"title"_s).toString();
            row.author = map.value(u"author"_s).toString();
            row.description = map.value(u"description"_s).toString();
            row.torrentUrl = map.value(u"torrentUrl"_s).toString();
            row.link = map.value(u"link"_s).toString();
            row.date = QDateTime::currentDateTime().addSecs(-map.value(u"secsAgo"_s, 3600).toLongLong());
            row.read = map.value(u"read"_s).toBool();
            m_unread += row.read ? 0 : 1;
            rows.append(row);
        }
        m_demoArticles.insert(it.key(), rows);
    }

    m_selectedPath.clear();
    emit settingsChanged();
    emit feedsChanged();
    emit rulesChanged();
    emit selectionChanged();
    rebuildArticles();
}
