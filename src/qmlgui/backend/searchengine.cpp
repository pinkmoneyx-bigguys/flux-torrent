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

#include "searchengine.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>

#include "base/addtorrentmanager.h"
#include "base/bittorrent/session.h"
#include "base/global.h"
#include "base/interfaces/iapplication.h"
#include "base/search/searchdownloadhandler.h"
#include "base/search/searchhandler.h"
#include "base/search/searchpluginmanager.h"
#include "base/settingsstorage.h"
#include "base/utils/foreignapps.h"
#include "jacredsearch.h"

namespace
{
    // Official plugins of github.com/qbittorrent/search-plugins that need no account or setup
    const QStringList OFFICIAL_PLUGINS {
        u"eztv"_s, u"limetorrents"_s, u"piratebay"_s, u"solidtorrents"_s, u"torlock"_s, u"torrentproject"_s, u"torrentscsv"_s
    };
    const QString OFFICIAL_PLUGIN_URL = u"https://raw.githubusercontent.com/qbittorrent/search-plugins/master/nova3/engines/%1.py"_s;

    const QString JACRED = u"jacred"_s;
    const QString JACRED_ENABLED_KEY = u"Flux/Search/JacRedEnabled"_s;
    const QString JACRED_URL_KEY = u"Flux/Search/JacRedUrl"_s;

    // without a profile (tests) the choices live here
    bool g_jacredEnabled = true;
    QString g_jacredUrl;
}

SearchEngine::SearchEngine(QObject *parent)
    : QObject(parent)
    , m_results {new SearchResultsModel(this)}
    , m_jacred {new JacRedSearch(this)}
{
    connect(m_jacred, &JacRedSearch::newResults, this, [this](const QList<JacRedResult> &results)
    {
        m_results->append(results);
    });
    connect(m_jacred, &JacRedSearch::finished, this, &SearchEngine::partFinished);

    // Development aid for window captures: {pattern, plugins: [...], results: [...]}
    if (const QString demo = qEnvironmentVariable("FLUX_DEMO_SEARCH"); !demo.isEmpty())
    {
        QFile file {demo};
        if (file.open(QIODevice::ReadOnly))
        {
            loadDemo(QJsonDocument::fromJson(file.readAll()).object().toVariantMap());
            return;
        }
    }

    recheckPython();
}

void SearchEngine::loadDemo(const QVariantMap &state)
{
    if (m_handler)
        m_handler->cancelSearch();

    m_demo = true;
    m_pythonAvailable = state.value(u"python"_s, true).toBool();
    m_pythonVersion = m_pythonAvailable ? u"3.13"_s : QString();
    m_pattern = state.value(u"pattern"_s).toString();
    m_plugins = state.value(u"plugins"_s).toList();
    m_pythonPlugins = m_plugins;
    m_enabledCount = 0;
    for (const QVariant &p : std::as_const(m_plugins))
        m_enabledCount += p.toMap().value(u"enabled"_s).toBool() ? 1 : 0;
    m_categories = {QVariantMap {{u"key"_s, u"all"_s}}, QVariantMap {{u"key"_s, u"movies"_s}},
        QVariantMap {{u"key"_s, u"tv"_s}}, QVariantMap {{u"key"_s, u"software"_s}}};
    m_pythonCategories = m_categories;
    m_results->setRows(state.value(u"results"_s).toList());
    m_status = state.value(u"status"_s, m_pattern.isEmpty() ? u"idle"_s : u"finished"_s).toString();
    m_error = state.value(u"error"_s).toString();
    emit pythonChanged();
    emit pluginsChanged();
    emit statusChanged();
}

SearchEngine::~SearchEngine()
{
    if (m_handler)
        m_handler->cancelSearch();
}

bool SearchEngine::jacredEnabled() const
{
    const SettingsStorage *storage = SettingsStorage::instance();
    return storage ? storage->loadValue<bool>(JACRED_ENABLED_KEY, true) : g_jacredEnabled;
}

QString SearchEngine::jacredUrl() const
{
    const SettingsStorage *storage = SettingsStorage::instance();
    const QString url = storage ? storage->loadValue<QString>(JACRED_URL_KEY) : g_jacredUrl;
    return url.isEmpty() ? JacRedSearch::DEFAULT_URL.toString() : url;
}

void SearchEngine::setJacredUrl(const QString &url)
{
    const QString value = url.trimmed();
    if (value == jacredUrl())
        return;
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(JACRED_URL_KEY, value);
    else
        g_jacredUrl = value;
    refreshPlugins();
}

SearchEngine *SearchEngine::create(QQmlEngine *, QJSEngine *)
{
    return new SearchEngine;
}

bool SearchEngine::pythonAvailable() const
{
    return m_pythonAvailable;
}

QString SearchEngine::pythonVersion() const
{
    return m_pythonVersion;
}

QVariantList SearchEngine::plugins() const
{
    return m_plugins;
}

int SearchEngine::enabledPluginCount() const
{
    return m_enabledCount;
}

QVariantList SearchEngine::categories() const
{
    return m_categories;
}

QString SearchEngine::status() const
{
    return m_status;
}

QString SearchEngine::error() const
{
    return m_error;
}

QString SearchEngine::pattern() const
{
    return m_pattern;
}

SearchResultsModel *SearchEngine::results() const
{
    return m_results;
}

bool SearchEngine::busy() const
{
    return m_busy > 0;
}

SearchPluginManager *SearchEngine::manager()
{
    // The plugin manager writes its engine files into the profile: only with the app's session running
    if (m_demo || !m_pythonAvailable || !BitTorrent::Session::instance())
        return nullptr;

    static bool connected = false;
    SearchPluginManager *mgr = SearchPluginManager::instance();
    if (!connected)
    {
        connected = true;
        connect(mgr, &SearchPluginManager::pluginEnabled, this, &SearchEngine::refreshPlugins);
        connect(mgr, &SearchPluginManager::pluginInstalled, this, [this](const QString &name)
        {
            setBusy(-1);
            refreshPlugins();
            emit message(tr("Installed %1").arg(manager()->pluginFullName(name)), false);
        });
        connect(mgr, &SearchPluginManager::pluginInstallationFailed, this, [this](const QString &name, const QString &reason)
        {
            setBusy(-1);
            emit message(tr("Could not install %1: %2").arg(name, reason), true);
        });
        connect(mgr, &SearchPluginManager::pluginUninstalled, this, &SearchEngine::refreshPlugins);
        connect(mgr, &SearchPluginManager::pluginUpdated, this, [this](const QString &name)
        {
            setBusy(-1);
            refreshPlugins();
            emit message(tr("Updated %1").arg(manager()->pluginFullName(name)), false);
        });
        connect(mgr, &SearchPluginManager::pluginUpdateFailed, this, [this](const QString &name, const QString &reason)
        {
            setBusy(-1);
            emit message(tr("Could not update %1: %2").arg(name, reason), true);
        });
        connect(mgr, &SearchPluginManager::checkForUpdatesFinished, this, [this](const QHash<QString, PluginVersion> &updates)
        {
            setBusy(-1);
            if (updates.isEmpty())
            {
                emit message(tr("All plugins are up to date."), false);
                return;
            }
            for (auto it = updates.cbegin(); it != updates.cend(); ++it)
            {
                setBusy(+1);
                manager()->updatePlugin(it.key());
            }
        });
        connect(mgr, &SearchPluginManager::checkForUpdatesFailed, this, [this](const QString &reason)
        {
            setBusy(-1);
            emit message(tr("Could not check for updates: %1").arg(reason), true);
        });
    }
    return mgr;
}

void SearchEngine::recheckPython()
{
    if (m_demo)
        return;
    if (!BitTorrent::Session::instance())
    {
        composePlugins();
        return;
    }

    const Utils::ForeignApps::PythonInfo info = Utils::ForeignApps::pythonInfo();
    const bool available = info.isValid() && info.isSupportedVersion();
    const QString version = info.isValid() ? info.version.toString() : QString();
    if ((available != m_pythonAvailable) || (version != m_pythonVersion))
    {
        m_pythonAvailable = available;
        m_pythonVersion = version;
        emit pythonChanged();
    }
    refreshPlugins();
}

void SearchEngine::refreshPlugins()
{
    SearchPluginManager *mgr = manager();
    if (!mgr)
    {
        // no Python: the built-in source alone
        if (!m_demo)
        {
            m_pythonPlugins.clear();
            m_pythonEnabledCount = 0;
            m_pythonCategories = {QVariantMap {{u"key"_s, u"all"_s}}};
        }
        composePlugins();
        return;
    }

    QList<QVariantMap> list;
    int enabled = 0;
    for (const QString &name : mgr->allPlugins())
    {
        const PluginInfo *info = mgr->pluginInfo(name);
        if (!info)
            continue;
        list.append({
            {u"name"_s, info->name},
            {u"fullName"_s, info->fullName},
            {u"url"_s, info->url},
            {u"version"_s, info->version.toString()},
            {u"enabled"_s, info->enabled},
            {u"categories"_s, info->supportedCategories}
        });
        enabled += info->enabled ? 1 : 0;
    }
    std::sort(list.begin(), list.end(), [](const QVariantMap &a, const QVariantMap &b)
    {
        return a.value(u"fullName"_s).toString().compare(b.value(u"fullName"_s).toString(), Qt::CaseInsensitive) < 0;
    });

    m_pythonPlugins.clear();
    for (const QVariantMap &p : std::as_const(list))
        m_pythonPlugins.append(p);
    m_pythonEnabledCount = enabled;

    m_pythonCategories = {QVariantMap {{u"key"_s, u"all"_s}}};
    for (const QString &category : mgr->supportedCategories())
    {
        if (category != u"all")
            m_pythonCategories.append(QVariantMap {{u"key"_s, category}});
    }
    composePlugins();
}

void SearchEngine::composePlugins()
{
    if (m_demo)
    {
        emit pluginsChanged();
        return;
    }

    const bool jacredOn = jacredEnabled();
    m_plugins = {QVariantMap {
        {u"name"_s, JACRED},
        {u"fullName"_s, tr("JacRed: movies and series")},
        {u"url"_s, jacredUrl()},
        {u"version"_s, QString()},
        {u"enabled"_s, jacredOn},
        {u"builtin"_s, true},
        {u"categories"_s, QStringList {u"movies"_s, u"tv"_s, u"anime"_s}}
    }};
    m_plugins.append(m_pythonPlugins);
    m_enabledCount = m_pythonEnabledCount + (jacredOn ? 1 : 0);

    m_categories = m_pythonCategories;
    if (m_categories.isEmpty())
        m_categories = {QVariantMap {{u"key"_s, u"all"_s}}};
    for (const QString &category : {u"movies"_s, u"tv"_s, u"anime"_s})
    {
        bool present = false;
        for (const QVariant &c : std::as_const(m_categories))
            present = present || (c.toMap().value(u"key"_s).toString() == category);
        if (!present && jacredOn)
            m_categories.append(QVariantMap {{u"key"_s, category}});
    }
    emit pluginsChanged();
}

void SearchEngine::setStatus(const QString &status, const QString &error)
{
    if ((status == m_status) && (error == m_error))
        return;

    m_status = status;
    m_error = error;
    emit statusChanged();
}

void SearchEngine::setBusy(const int delta)
{
    const bool was = busy();
    m_busy = std::max(0, m_busy + delta);
    if (busy() != was)
        emit busyChanged();
}

void SearchEngine::start(const QString &pattern, const QString &category, const QString &plugin)
{
    const QString text = pattern.trimmed();
    if (m_demo || text.isEmpty())
        return;

    stop();
    m_results->clear();
    m_pattern = text;
    const QString cat = category.isEmpty() ? u"all"_s : category;

    // which parts take part: JacRed (when on, or picked alone) and the Python plugins
    const bool useJacred = ((plugin == JACRED) || ((plugin != JACRED) && jacredEnabled() && (plugin == u"enabled" || plugin == u"all" || plugin.isEmpty())))
        && JacRedSearch::covers(cat);
    QStringList plugins;
    if (SearchPluginManager *mgr = manager(); mgr && (plugin != JACRED))
    {
        if (plugin == u"all")
            plugins = mgr->allPlugins();
        else if ((plugin == u"enabled") || plugin.isEmpty())
            plugins = mgr->enabledPlugins();
        else
            plugins = {plugin};
    }

    if (!useJacred && plugins.isEmpty())
    {
        setStatus(u"failed"_s, JacRedSearch::covers(cat) ? tr("No search sources are enabled.")
                                                          : tr("No enabled source searches this category."));
        return;
    }

    m_pendingParts = (useJacred ? 1 : 0) + (plugins.isEmpty() ? 0 : 1);
    m_failedParts = 0;
    m_partError.clear();
    m_status = u"running"_s;
    m_error.clear();
    emit statusChanged();

    if (!plugins.isEmpty())
    {
        SearchHandler *handler = manager()->startSearch(text, cat, plugins);
        m_handler = handler;
        connect(handler, &SearchHandler::newSearchResults, this, [this, handler](const QList<SearchResult> &results)
        {
            if (handler == m_handler)
                m_results->append(results);
        });
        connect(handler, &SearchHandler::searchFinished, this, [this, handler](const bool cancelled)
        {
            if (handler == m_handler)
                partFinished(cancelled ? u"cancelled"_s : QString());
            handler->deleteLater();
        });
        connect(handler, &SearchHandler::searchFailed, this, [this, handler](const QString &errorMessage)
        {
            if (handler == m_handler)
                partFinished(errorMessage.isEmpty() ? tr("The search failed.") : errorMessage);
            handler->deleteLater();
        });
    }
    if (useJacred)
        m_jacred->start(jacredUrl(), text, cat);
}

void SearchEngine::partFinished(const QString &error)
{
    if (m_pendingParts <= 0)
        return;
    --m_pendingParts;
    if (!error.isEmpty() && (error != u"cancelled"))
    {
        ++m_failedParts;
        m_partError = error;
    }
    if (m_pendingParts > 0)
        return;

    if (error == u"cancelled")
        setStatus(u"cancelled"_s);
    else if ((m_failedParts > 0) && (m_results->rowCount() == 0))
        setStatus(u"failed"_s, m_partError);
    else
        setStatus(u"finished"_s);
}

void SearchEngine::stop()
{
    const bool running = (m_pendingParts > 0);
    if (m_handler && m_handler->isActive())
        m_handler->cancelSearch();
    m_jacred->cancel();
    if (running)
    {
        m_pendingParts = 0;
        setStatus(u"cancelled"_s);
    }
}

bool SearchEngine::addSource(const QString &source)
{
    auto *app = dynamic_cast<IApplication *>(QCoreApplication::instance());
    if (!app || !app->addTorrentManager())
        return false;
    return app->addTorrentManager()->addTorrent(source);
}

bool SearchEngine::download(const int row)
{
    const SearchRow *r = m_results->rowAt(row);
    if (!r || r->fileUrl.isEmpty())
        return false;

    bool ok = true;
    SearchPluginManager *mgr = manager();
    if (r->fileUrl.startsWith(u"magnet:", Qt::CaseInsensitive) || !mgr || !mgr->pluginInfo(r->engine))
    {
        // magnets go straight in; http links are fetched by the add-torrent manager
        ok = addSource(r->fileUrl);
    }
    else
    {
        // the plugin knows how to fetch its own .torrent links (cookies, redirects)
        SearchDownloadHandler *handler = mgr->downloadTorrent(r->engine, r->fileUrl);
        connect(handler, &SearchDownloadHandler::downloadFinished, this, [this, handler](const QString &path, const QString &errorMessage)
        {
            if (!errorMessage.isEmpty() || !addSource(path))
                emit message(errorMessage.isEmpty() ? tr("Could not add the torrent.") : errorMessage, true);
            handler->deleteLater();
        });
    }

    if (ok)
    {
        m_results->markDownloaded(row);
        emit message(tr("Added “%1”").arg(r->name), false);
    }
    return ok;
}

void SearchEngine::openPage(const int row)
{
    const SearchRow *r = m_results->rowAt(row);
    if (r)
        openUrl(r->descrLink.isEmpty() ? r->siteUrl : r->descrLink);
}

void SearchEngine::openUrl(const QString &url)
{
    const QUrl target {url};
    if (target.isValid() && !target.isLocalFile() && (target.scheme().startsWith(u"http")))
        QDesktopServices::openUrl(target);
}

void SearchEngine::enablePlugin(const QString &name, const bool enabled)
{
    if (name == JACRED)
    {
        if (SettingsStorage *storage = SettingsStorage::instance())
            storage->storeValue(JACRED_ENABLED_KEY, enabled);
        else
            g_jacredEnabled = enabled;
        composePlugins();
        return;
    }
    if (SearchPluginManager *mgr = manager())
    {
        mgr->enablePlugin(name, enabled);
        refreshPlugins();
    }
}

void SearchEngine::uninstallPlugin(const QString &name)
{
    if (SearchPluginManager *mgr = manager())
    {
        const QString fullName = mgr->pluginFullName(name);
        if (mgr->uninstallPlugin(name))
            emit message(tr("Removed %1").arg(fullName), false);
        refreshPlugins();
    }
}

void SearchEngine::installPlugin(const QString &source)
{
    SearchPluginManager *mgr = manager();
    QString path = source.trimmed();
    if (!mgr || path.isEmpty())
        return;

    if (const QUrl url {path}; url.isLocalFile())
        path = url.toLocalFile();
    setBusy(+1);
    mgr->installPlugin(path);
}

void SearchEngine::installOfficialPlugins()
{
    for (const QString &name : OFFICIAL_PLUGINS)
        installPlugin(OFFICIAL_PLUGIN_URL.arg(name));
}

void SearchEngine::checkForUpdates()
{
    if (SearchPluginManager *mgr = manager())
    {
        setBusy(+1);
        mgr->checkForUpdates();
    }
}
