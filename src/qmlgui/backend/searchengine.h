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

#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

#include "searchresults.h"

class QJSEngine;
class QQmlEngine;
class JacRedSearch;
class SearchHandler;
class SearchPluginManager;

// Tracker search for QML: Python and plugin state, one search at a time with its results, downloads
// of results, and plugin management. Wraps qBittorrent's SearchPluginManager (Python "nova" plugins),
// plus a built-in source that needs no Python: JacRed ("jacred" in `plugins`, first, on by default),
// the aggregator of the Russian movie and series trackers. Both answer into the same results.
// FLUX_DEMO_SEARCH=<json file> fills the results without Python, for window captures.
class SearchEngine : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(SearchEngine)
    QML_ELEMENT
    QML_SINGLETON

    // Python 3.9+ found (searching needs it)
    Q_PROPERTY(bool pythonAvailable READ pythonAvailable NOTIFY pythonChanged FINAL)
    Q_PROPERTY(QString pythonVersion READ pythonVersion NOTIFY pythonChanged FINAL)
    // [{name, fullName, url, version, enabled, categories}] sorted by full name
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY pluginsChanged FINAL)
    Q_PROPERTY(int enabledPluginCount READ enabledPluginCount NOTIFY pluginsChanged FINAL)
    // [{key, label}]: "all" first, then the categories of the enabled plugins
    Q_PROPERTY(QVariantList categories READ categories NOTIFY pluginsChanged FINAL)
    // "idle", "running", "finished", "cancelled", "failed"
    Q_PROPERTY(QString status READ status NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY statusChanged FINAL)
    Q_PROPERTY(QString pattern READ pattern NOTIFY statusChanged FINAL)
    Q_PROPERTY(SearchResultsModel *results READ results CONSTANT FINAL)
    // Plugin install/update in progress
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    // The JacRed server (a mirror can be set instead of the default)
    Q_PROPERTY(QString jacredUrl READ jacredUrl WRITE setJacredUrl NOTIFY pluginsChanged FINAL)

public:
    explicit SearchEngine(QObject *parent = nullptr);
    ~SearchEngine() override;

    static SearchEngine *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool pythonAvailable() const;
    QString pythonVersion() const;
    QVariantList plugins() const;
    int enabledPluginCount() const;
    QVariantList categories() const;
    QString status() const;
    QString error() const;
    QString pattern() const;
    SearchResultsModel *results() const;
    bool busy() const;
    QString jacredUrl() const;
    void setJacredUrl(const QString &url);

    // `plugin`: "enabled" (all enabled plugins), "all", or one plugin name
    Q_INVOKABLE void start(const QString &pattern, const QString &category, const QString &plugin);
    Q_INVOKABLE void stop();
    // Adds the result at source row `row` to the transfers; returns false if it cannot be added
    Q_INVOKABLE bool download(int row);
    Q_INVOKABLE void openPage(int row);
    Q_INVOKABLE void openUrl(const QString &url);

    Q_INVOKABLE void recheckPython();
    Q_INVOKABLE void enablePlugin(const QString &name, bool enabled);
    Q_INVOKABLE void uninstallPlugin(const QString &name);
    // A plugin .py URL or local file (file:// URL or path)
    Q_INVOKABLE void installPlugin(const QString &source);
    // The official qBittorrent plugins that work without configuration
    Q_INVOKABLE void installOfficialPlugins();
    Q_INVOKABLE void checkForUpdates();
    // Tests and the demo file: {python, pattern, status, error, plugins: [...], results: [...]};
    // detaches from Python and the plugin manager
    Q_INVOKABLE void loadDemo(const QVariantMap &state);

signals:
    void pythonChanged();
    void pluginsChanged();
    void statusChanged();
    void busyChanged();
    // Outcome of plugin management and downloads, for a toast or an inline note
    void message(const QString &text, bool isError);

private:
    SearchPluginManager *manager();
    void refreshPlugins();
    // m_plugins, m_categories and the enabled count: JacRed first, then the Python plugins
    void composePlugins();
    void setStatus(const QString &status, const QString &error = {});
    void setBusy(int delta);
    bool addSource(const QString &source);
    bool jacredEnabled() const;
    // a part of the search (Python plugins or JacRed) is over; the search is when all are
    void partFinished(const QString &error);

    bool m_pythonAvailable = false;
    QString m_pythonVersion;
    QVariantList m_plugins;
    QVariantList m_categories;
    int m_enabledCount = 0;
    QString m_status = QStringLiteral("idle");
    QString m_error;
    QString m_pattern;
    SearchResultsModel *m_results = nullptr;
    QPointer<SearchHandler> m_handler;
    JacRedSearch *m_jacred = nullptr;
    int m_pendingParts = 0;
    int m_failedParts = 0;
    QString m_partError;
    QVariantList m_pythonPlugins;
    QVariantList m_pythonCategories;
    int m_pythonEnabledCount = 0;
    int m_busy = 0;
    bool m_demo = false;
};
