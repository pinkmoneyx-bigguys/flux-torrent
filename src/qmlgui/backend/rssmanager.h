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
#include <QObject>
#include <QPointer>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

namespace RSS
{
    class Article;
    class Item;
}

// One article as the list and the reader show it
struct RssArticleRow
{
    QString guid;
    QString feedUrl;
    QString feedName;
    QString title;
    QString author;
    QString description;
    QString torrentUrl;
    QString link;
    QDateTime date;
    bool read = false;
    QPointer<RSS::Article> article; // null for demo rows
};

// Articles of the selected feed or folder, newest first, after the search and "unread only" filters
class RssArticlesModel : public QAbstractListModel
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(RssArticlesModel)
    QML_ELEMENT
    QML_UNCREATABLE("Owned by RssManager")

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged FINAL)

public:
    enum Role
    {
        GuidRole = Qt::UserRole + 1,
        FeedNameRole,
        TitleRole,
        AuthorRole,
        DescriptionRole,
        SnippetRole,
        TorrentUrlRole,
        LinkRole,
        DateRole,
        ReadRole
    };

    explicit RssArticlesModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setRows(QList<RssArticleRow> rows);
    const RssArticleRow *rowAt(int i) const;
    void setRead(int i);

signals:
    void countChanged();

private:
    QList<RssArticleRow> m_rows;
};

// RSS for QML: the feed tree, the articles of the selected item with a reader, feed management and the
// auto-download rules. Wraps RSS::Session and RSS::AutoDownloader; FLUX_DEMO_RSS=<json file> (and
// loadDemo in tests) feeds it without them.
class RssManager : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(RssManager)
    QML_ELEMENT
    QML_SINGLETON

    // Feeds fetch on schedule only when processing is on (off by default in qBittorrent)
    Q_PROPERTY(bool processingEnabled READ processingEnabled WRITE setProcessingEnabled NOTIFY settingsChanged FINAL)
    Q_PROPERTY(bool autoDownloadEnabled READ autoDownloadEnabled WRITE setAutoDownloadEnabled NOTIFY settingsChanged FINAL)
    // Minutes between refreshes
    Q_PROPERTY(int refreshInterval READ refreshInterval WRITE setRefreshInterval NOTIFY settingsChanged FINAL)
    // Flattened tree: [{path, name, folder, depth, url, unread, total, loading, error}]
    Q_PROPERTY(QVariantList feeds READ feeds NOTIFY feedsChanged FINAL)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY feedsChanged FINAL)
    // "" is every feed
    Q_PROPERTY(QString selectedPath READ selectedPath WRITE setSelectedPath NOTIFY selectionChanged FINAL)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY selectionChanged FINAL)
    Q_PROPERTY(bool unreadOnly READ unreadOnly WRITE setUnreadOnly NOTIFY selectionChanged FINAL)
    Q_PROPERTY(RssArticlesModel *articles READ articles CONSTANT FINAL)
    // [{name, enabled, mustContain, mustNotContain, useRegex, smartFilter, episodeFilter, ignoreDays,
    //   feeds (URLs), category, savePath, lastMatch}]
    Q_PROPERTY(QVariantList rules READ rules NOTIFY rulesChanged FINAL)

public:
    explicit RssManager(QObject *parent = nullptr);

    static RssManager *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool processingEnabled() const;
    void setProcessingEnabled(bool enabled);
    bool autoDownloadEnabled() const;
    void setAutoDownloadEnabled(bool enabled);
    int refreshInterval() const;
    void setRefreshInterval(int minutes);
    QVariantList feeds() const;
    int unreadCount() const;
    QString selectedPath() const;
    void setSelectedPath(const QString &path);
    QString search() const;
    void setSearch(const QString &search);
    bool unreadOnly() const;
    void setUnreadOnly(bool on);
    RssArticlesModel *articles() const;
    QVariantList rules() const;

    // Returns "" on success or the error text
    Q_INVOKABLE QString addFeed(const QString &url, const QString &folderPath);
    Q_INVOKABLE QString addFolder(const QString &name);
    Q_INVOKABLE QString rename(const QString &path, const QString &newName);
    Q_INVOKABLE QString remove(const QString &path);
    Q_INVOKABLE void refresh(const QString &path);
    Q_INVOKABLE void markAllRead(const QString &path);

    Q_INVOKABLE void markRead(int row);
    // Adds the article's torrent; returns false when it has none
    Q_INVOKABLE bool download(int row);
    Q_INVOKABLE void openLink(int row);

    // `rule` as in `rules`; an empty oldName adds a new rule. Returns "" or the error text.
    Q_INVOKABLE QString saveRule(const QVariantMap &rule, const QString &oldName);
    Q_INVOKABLE void removeRule(const QString &name);
    // Titles of the known articles of the rule's feeds that the rule would download (at most 50)
    Q_INVOKABLE QStringList previewRule(const QVariantMap &rule) const;

    Q_INVOKABLE void loadDemo(const QVariantMap &state);

signals:
    void settingsChanged();
    void feedsChanged();
    void selectionChanged();
    void rulesChanged();

private:
    void attach();
    void rebuildFeeds();
    void rebuildArticles();
    void rebuildRules();
    void scheduleArticles();
    QList<RssArticleRow> collectArticles() const;

    RssArticlesModel *m_articles = nullptr;
    QVariantList m_feeds;
    QVariantList m_rules;
    int m_unread = 0;
    QString m_selectedPath;
    QString m_search;
    bool m_unreadOnly = false;
    QTimer m_articlesTimer;
    QTimer m_feedsTimer;

    bool m_demo = false;
    bool m_demoProcessing = false;
    bool m_demoAutoDownload = false;
    int m_demoInterval = 30;
    QHash<QString, QList<RssArticleRow>> m_demoArticles; // by feed path
};
