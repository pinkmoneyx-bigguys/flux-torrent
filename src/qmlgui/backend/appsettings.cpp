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

#include "appsettings.h"

#include <QRandomGenerator>

#include "base/bittorrent/session.h"
#include "base/bittorrent/sharelimits.h"
#include "base/bittorrent/torrent.h"
#include "base/bittorrent/torrentcontentlayout.h"
#include "base/global.h"
#include "base/net/portforwarder.h"
#include "base/net/proxyconfigurationmanager.h"
#include "base/path.h"

using BitTorrent::Session;

namespace
{
    // key -> default; also the full list of keys
    const QVariantMap &defaults()
    {
        static const QVariantMap map {
            // Downloads
            {u"savePath"_s, u"C:/Users/Public/Downloads"_s},
            {u"downloadPathEnabled"_s, false},
            {u"downloadPath"_s, QString()},
            {u"appendExtension"_s, false},
            {u"preallocation"_s, false},
            {u"addStopped"_s, false},
            {u"addToQueueTop"_s, false},
            {u"contentLayout"_s, u"original"_s},
            // Speed (KiB/s, 0 = unlimited)
            {u"dlLimit"_s, 0},
            {u"upLimit"_s, 0},
            {u"altDlLimit"_s, 10240},
            {u"altUpLimit"_s, 10240},
            {u"altSpeedEnabled"_s, false},
            {u"schedulerEnabled"_s, false},
            {u"utpRateLimited"_s, true},
            {u"includeOverhead"_s, false},
            {u"ignoreLimitsOnLAN"_s, true},
            // Connection
            {u"port"_s, 8999},
            {u"upnp"_s, true},
            {u"maxConnections"_s, 500},
            {u"maxConnectionsPerTorrent"_s, 100},
            {u"maxUploads"_s, 20},
            {u"maxUploadsPerTorrent"_s, 4},
            {u"protocol"_s, u"both"_s},
            {u"proxyType"_s, u"none"_s},
            {u"proxyHost"_s, QString()},
            {u"proxyPort"_s, 8080},
            {u"proxyAuth"_s, false},
            {u"proxyUser"_s, QString()},
            {u"proxyPassword"_s, QString()},
            {u"proxyPeers"_s, false},
            // BitTorrent
            {u"dht"_s, true},
            {u"pex"_s, true},
            {u"lsd"_s, true},
            {u"encryption"_s, u"prefer"_s},
            {u"anonymous"_s, false},
            {u"queueing"_s, true},
            {u"maxActiveDownloads"_s, 3},
            {u"maxActiveUploads"_s, 3},
            {u"maxActiveTorrents"_s, 5},
            {u"ignoreSlow"_s, false},
            {u"ratioLimitEnabled"_s, false},
            {u"ratioLimit"_s, 2.0},
            {u"seedTimeEnabled"_s, false},
            {u"seedTimeMinutes"_s, 1440},
            {u"shareAction"_s, u"stop"_s},
            {u"addTrackersEnabled"_s, false},
            {u"additionalTrackers"_s, QString()}
        };
        return map;
    }

    QString checkRange(const QVariant &v, const int min, const int max)
    {
        bool ok = false;
        const int n = v.toInt(&ok);
        if (!ok || (n < min) || (n > max))
            return QObject::tr("Enter a number from %1 to %2.").arg(min).arg(max);
        return {};
    }

    // -1 (or anything below 1) means unlimited for connection and queue counts
    int countOf(const QVariant &v)
    {
        const int n = v.toInt();
        return (n > 0) ? n : -1;
    }

    const QHash<QString, int> &enumValues(const QString &key)
    {
        static const QHash<QString, QHash<QString, int>> all {
            {u"contentLayout"_s, {{u"original"_s, int(BitTorrent::TorrentContentLayout::Original)},
                                  {u"subfolder"_s, int(BitTorrent::TorrentContentLayout::Subfolder)},
                                  {u"noSubfolder"_s, int(BitTorrent::TorrentContentLayout::NoSubfolder)}}},
            {u"protocol"_s, {{u"both"_s, int(BitTorrent::BTProtocol::Both)}, {u"tcp"_s, int(BitTorrent::BTProtocol::TCP)},
                             {u"utp"_s, int(BitTorrent::BTProtocol::UTP)}}},
            {u"proxyType"_s, {{u"none"_s, int(Net::ProxyType::None)}, {u"http"_s, int(Net::ProxyType::HTTP)},
                              {u"socks5"_s, int(Net::ProxyType::SOCKS5)}, {u"socks4"_s, int(Net::ProxyType::SOCKS4)}}},
            {u"encryption"_s, {{u"prefer"_s, 0}, {u"require"_s, 1}, {u"disable"_s, 2}}},
            {u"shareAction"_s, {{u"stop"_s, int(BitTorrent::ShareLimitAction::Stop)}, {u"remove"_s, int(BitTorrent::ShareLimitAction::Remove)},
                                {u"removeContent"_s, int(BitTorrent::ShareLimitAction::RemoveWithContent)},
                                {u"superSeed"_s, int(BitTorrent::ShareLimitAction::EnableSuperSeeding)}}}
        };
        static const QHash<QString, int> none;
        const auto it = all.constFind(key);
        return (it != all.cend()) ? it.value() : none;
    }

    QString enumName(const QString &key, const int value)
    {
        const QHash<QString, int> &values = enumValues(key);
        for (auto it = values.cbegin(); it != values.cend(); ++it)
        {
            if (it.value() == value)
                return it.key();
        }
        return defaults().value(key).toString();
    }

    QString checkEnum(const QString &key, const QVariant &v)
    {
        return enumValues(key).contains(v.toString()) ? QString() : QObject::tr("Unknown option.");
    }
}

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
    if (Session::instance())
        registerLive();
    else
        registerMemory();
}

AppSettings *AppSettings::create(QQmlEngine *, QJSEngine *)
{
    return new AppSettings;
}

int AppSettings::revision() const
{
    return m_revision;
}

QStringList AppSettings::keys() const
{
    return defaults().keys();
}

QVariant AppSettings::value(const QString &key) const
{
    const auto it = m_entries.constFind(key);
    return (it != m_entries.cend()) ? it->get() : QVariant();
}

QString AppSettings::setValue(const QString &key, const QVariant &value)
{
    const auto it = m_entries.constFind(key);
    if (it == m_entries.cend())
        return tr("Unknown setting.");
    if (it->get() == value)
        return {};

    const QString error = it->set(value);
    if (error.isEmpty())
    {
        ++m_revision;
        emit changed(key);
    }
    return error;
}

int AppSettings::randomPort() const
{
    return static_cast<int>(QRandomGenerator::global()->bounded(1024, 65535));
}

void AppSettings::registerMemory()
{
    m_memory = defaults();
    for (const QString &key : defaults().keys())
    {
        m_entries.insert(key, {
            [this, key] { return m_memory.value(key); },
            [this, key](const QVariant &v) -> QString
            {
                const QVariant def = defaults().value(key);
                if (!enumValues(key).isEmpty())
                {
                    if (const QString e = checkEnum(key, v); !e.isEmpty())
                        return e;
                }
                else if ((key == u"port") || (key == u"proxyPort"))
                {
                    if (const QString e = checkRange(v, 1, 65535); !e.isEmpty())
                        return e;
                }
                else if ((key == u"savePath") && v.toString().trimmed().isEmpty())
                {
                    return tr("Choose a folder.");
                }
                QVariant stored = v;
                if (stored.convert(def.metaType()))
                    m_memory.insert(key, stored);
                else
                    m_memory.insert(key, v);
                return {};
            }
        });
    }
}

void AppSettings::registerLive()
{
    Session *s = Session::instance();

    const auto boolEntry = [this](const QString &key, std::function<bool ()> get, std::function<void (bool)> set)
    {
        m_entries.insert(key, {[get] { return QVariant(get()); }, [set](const QVariant &v) { set(v.toBool()); return QString(); }});
    };
    const auto kibEntry = [this](const QString &key, std::function<int ()> get, std::function<void (int)> set)
    {
        m_entries.insert(key, {
            [get] { return QVariant(get() / 1024); },
            [set](const QVariant &v) -> QString
            {
                if (const QString e = checkRange(v, 0, 2000000); !e.isEmpty())
                    return e;
                set(v.toInt() * 1024);
                return {};
            }});
    };
    const auto countEntry = [this](const QString &key, std::function<int ()> get, std::function<void (int)> set)
    {
        m_entries.insert(key, {
            [get] { return QVariant(get()); },
            [set](const QVariant &v) -> QString
            {
                if (const QString e = checkRange(v, -1, 100000); !e.isEmpty())
                    return e;
                set(countOf(v));
                return {};
            }});
    };
    const auto enumEntry = [this](const QString &key, std::function<int ()> get, std::function<void (int)> set)
    {
        m_entries.insert(key, {
            [key, get] { return QVariant(enumName(key, get())); },
            [key, set](const QVariant &v) -> QString
            {
                if (const QString e = checkEnum(key, v); !e.isEmpty())
                    return e;
                set(enumValues(key).value(v.toString()));
                return {};
            }});
    };
    const auto pathEntry = [this](const QString &key, std::function<Path ()> get, std::function<void (const Path &)> set, const bool required)
    {
        m_entries.insert(key, {
            [get] { return QVariant(get().toString()); },
            [set, required](const QVariant &v) -> QString
            {
                const QString text = v.toString().trimmed();
                if (required && text.isEmpty())
                    return tr("Choose a folder.");
                set(Path(text));
                return {};
            }});
    };

    // --- Downloads ---
    pathEntry(u"savePath"_s, [s] { return s->savePath(); }, [s](const Path &p) { s->setSavePath(p); }, true);
    boolEntry(u"downloadPathEnabled"_s, [s] { return s->isDownloadPathEnabled(); }, [s](bool b) { s->setDownloadPathEnabled(b); });
    pathEntry(u"downloadPath"_s, [s] { return s->downloadPath(); }, [s](const Path &p) { s->setDownloadPath(p); }, false);
    boolEntry(u"appendExtension"_s, [s] { return s->isAppendExtensionEnabled(); }, [s](bool b) { s->setAppendExtensionEnabled(b); });
    boolEntry(u"preallocation"_s, [s] { return s->isPreallocationEnabled(); }, [s](bool b) { s->setPreallocationEnabled(b); });
    boolEntry(u"addStopped"_s, [s] { return s->isAddTorrentStopped(); }, [s](bool b) { s->setAddTorrentStopped(b); });
    boolEntry(u"addToQueueTop"_s, [s] { return s->isAddTorrentToQueueTop(); }, [s](bool b) { s->setAddTorrentToQueueTop(b); });
    enumEntry(u"contentLayout"_s, [s] { return int(s->torrentContentLayout()); },
        [s](int v) { s->setTorrentContentLayout(static_cast<BitTorrent::TorrentContentLayout>(v)); });

    // --- Speed ---
    kibEntry(u"dlLimit"_s, [s] { return s->globalDownloadSpeedLimit(); }, [s](int v) { s->setGlobalDownloadSpeedLimit(v); });
    kibEntry(u"upLimit"_s, [s] { return s->globalUploadSpeedLimit(); }, [s](int v) { s->setGlobalUploadSpeedLimit(v); });
    kibEntry(u"altDlLimit"_s, [s] { return s->altGlobalDownloadSpeedLimit(); }, [s](int v) { s->setAltGlobalDownloadSpeedLimit(v); });
    kibEntry(u"altUpLimit"_s, [s] { return s->altGlobalUploadSpeedLimit(); }, [s](int v) { s->setAltGlobalUploadSpeedLimit(v); });
    boolEntry(u"altSpeedEnabled"_s, [s] { return s->isAltGlobalSpeedLimitEnabled(); }, [s](bool b) { s->setAltGlobalSpeedLimitEnabled(b); });
    boolEntry(u"schedulerEnabled"_s, [s] { return s->isBandwidthSchedulerEnabled(); }, [s](bool b) { s->setBandwidthSchedulerEnabled(b); });
    boolEntry(u"utpRateLimited"_s, [s] { return s->isUTPRateLimited(); }, [s](bool b) { s->setUTPRateLimited(b); });
    boolEntry(u"includeOverhead"_s, [s] { return s->includeOverheadInLimits(); }, [s](bool b) { s->setIncludeOverheadInLimits(b); });
    boolEntry(u"ignoreLimitsOnLAN"_s, [s] { return s->ignoreLimitsOnLAN(); }, [s](bool b) { s->setIgnoreLimitsOnLAN(b); });

    // --- Connection ---
    m_entries.insert(u"port"_s, {
        [s] { return QVariant(s->port()); },
        [s](const QVariant &v) -> QString
        {
            if (const QString e = checkRange(v, 1, 65535); !e.isEmpty())
                return e;
            s->setPort(v.toInt());
            return {};
        }});
    boolEntry(u"upnp"_s, [] { return Net::PortForwarder::instance() && Net::PortForwarder::instance()->isEnabled(); },
        [](bool b) { if (Net::PortForwarder::instance()) Net::PortForwarder::instance()->setEnabled(b); });
    countEntry(u"maxConnections"_s, [s] { return s->maxConnections(); }, [s](int v) { s->setMaxConnections(v); });
    countEntry(u"maxConnectionsPerTorrent"_s, [s] { return s->maxConnectionsPerTorrent(); }, [s](int v) { s->setMaxConnectionsPerTorrent(v); });
    countEntry(u"maxUploads"_s, [s] { return s->maxUploads(); }, [s](int v) { s->setMaxUploads(v); });
    countEntry(u"maxUploadsPerTorrent"_s, [s] { return s->maxUploadsPerTorrent(); }, [s](int v) { s->setMaxUploadsPerTorrent(v); });
    enumEntry(u"protocol"_s, [s] { return int(s->btProtocol()); }, [s](int v) { s->setBTProtocol(static_cast<BitTorrent::BTProtocol>(v)); });
    boolEntry(u"proxyPeers"_s, [s] { return s->isProxyPeerConnectionsEnabled(); }, [s](bool b) { s->setProxyPeerConnectionsEnabled(b); });

    // Proxy fields edit one ProxyConfiguration
    const auto proxy = [] { return Net::ProxyConfigurationManager::instance()->proxyConfiguration(); };
    const auto setProxy = [](const std::function<void (Net::ProxyConfiguration &)> &change)
    {
        Net::ProxyConfiguration config = Net::ProxyConfigurationManager::instance()->proxyConfiguration();
        change(config);
        Net::ProxyConfigurationManager::instance()->setProxyConfiguration(config);
    };
    enumEntry(u"proxyType"_s, [proxy] { return int(proxy().type); },
        [setProxy](int v) { setProxy([v](Net::ProxyConfiguration &c) { c.type = static_cast<Net::ProxyType>(v); }); });
    m_entries.insert(u"proxyHost"_s, {[proxy] { return QVariant(proxy().ip); },
        [setProxy](const QVariant &v) { setProxy([v](Net::ProxyConfiguration &c) { c.ip = v.toString().trimmed(); }); return QString(); }});
    m_entries.insert(u"proxyPort"_s, {[proxy] { return QVariant(int(proxy().port)); },
        [setProxy](const QVariant &v) -> QString
        {
            if (const QString e = checkRange(v, 1, 65535); !e.isEmpty())
                return e;
            setProxy([v](Net::ProxyConfiguration &c) { c.port = static_cast<ushort>(v.toInt()); });
            return {};
        }});
    boolEntry(u"proxyAuth"_s, [proxy] { return proxy().authEnabled; },
        [setProxy](bool b) { setProxy([b](Net::ProxyConfiguration &c) { c.authEnabled = b; }); });
    m_entries.insert(u"proxyUser"_s, {[proxy] { return QVariant(proxy().username); },
        [setProxy](const QVariant &v) { setProxy([v](Net::ProxyConfiguration &c) { c.username = v.toString(); }); return QString(); }});
    m_entries.insert(u"proxyPassword"_s, {[proxy] { return QVariant(proxy().password); },
        [setProxy](const QVariant &v) { setProxy([v](Net::ProxyConfiguration &c) { c.password = v.toString(); }); return QString(); }});

    // --- BitTorrent ---
    boolEntry(u"dht"_s, [s] { return s->isDHTEnabled(); }, [s](bool b) { s->setDHTEnabled(b); });
    boolEntry(u"pex"_s, [s] { return s->isPeXEnabled(); }, [s](bool b) { s->setPeXEnabled(b); });
    boolEntry(u"lsd"_s, [s] { return s->isLSDEnabled(); }, [s](bool b) { s->setLSDEnabled(b); });
    enumEntry(u"encryption"_s, [s] { return s->encryption(); }, [s](int v) { s->setEncryption(v); });
    boolEntry(u"anonymous"_s, [s] { return s->isAnonymousModeEnabled(); }, [s](bool b) { s->setAnonymousModeEnabled(b); });
    boolEntry(u"queueing"_s, [s] { return s->isQueueingSystemEnabled(); }, [s](bool b) { s->setQueueingSystemEnabled(b); });
    countEntry(u"maxActiveDownloads"_s, [s] { return s->maxActiveDownloads(); }, [s](int v) { s->setMaxActiveDownloads(v); });
    countEntry(u"maxActiveUploads"_s, [s] { return s->maxActiveUploads(); }, [s](int v) { s->setMaxActiveUploads(v); });
    countEntry(u"maxActiveTorrents"_s, [s] { return s->maxActiveTorrents(); }, [s](int v) { s->setMaxActiveTorrents(v); });
    boolEntry(u"ignoreSlow"_s, [s] { return s->ignoreSlowTorrentsForQueueing(); }, [s](bool b) { s->setIgnoreSlowTorrentsForQueueing(b); });

    // A ratio or time limit is "off" at -1; the last value is kept to restore when it is turned on again
    if (s->globalMaxRatio() >= 0)
        m_lastRatio = s->globalMaxRatio();
    if (s->globalMaxSeedingMinutes() >= 0)
        m_lastSeedMinutes = s->globalMaxSeedingMinutes();
    boolEntry(u"ratioLimitEnabled"_s, [s] { return s->globalMaxRatio() >= 0; },
        [this, s](bool b) { s->setGlobalMaxRatio(b ? m_lastRatio : -1); });
    m_entries.insert(u"ratioLimit"_s, {
        [this, s] { return QVariant(s->globalMaxRatio() >= 0 ? s->globalMaxRatio() : m_lastRatio); },
        [this, s](const QVariant &v) -> QString
        {
            bool ok = false;
            const double r = v.toDouble(&ok);
            if (!ok || (r < 0) || (r > 9998))
                return tr("Enter a ratio from 0 to 9998.");
            m_lastRatio = r;
            if (s->globalMaxRatio() >= 0)
                s->setGlobalMaxRatio(r);
            return {};
        }});
    boolEntry(u"seedTimeEnabled"_s, [s] { return s->globalMaxSeedingMinutes() >= 0; },
        [this, s](bool b) { s->setGlobalMaxSeedingMinutes(b ? m_lastSeedMinutes : -1); });
    m_entries.insert(u"seedTimeMinutes"_s, {
        [this, s] { return QVariant(s->globalMaxSeedingMinutes() >= 0 ? s->globalMaxSeedingMinutes() : m_lastSeedMinutes); },
        [this, s](const QVariant &v) -> QString
        {
            if (const QString e = checkRange(v, 1, 525600); !e.isEmpty())
                return e;
            m_lastSeedMinutes = v.toInt();
            if (s->globalMaxSeedingMinutes() >= 0)
                s->setGlobalMaxSeedingMinutes(m_lastSeedMinutes);
            return {};
        }});
    enumEntry(u"shareAction"_s, [s] { return int(s->shareLimitAction()); },
        [s](int v) { s->setShareLimitAction(static_cast<BitTorrent::ShareLimitAction>(v)); });
    boolEntry(u"addTrackersEnabled"_s, [s] { return s->isAddTrackersEnabled(); }, [s](bool b) { s->setAddTrackersEnabled(b); });
    m_entries.insert(u"additionalTrackers"_s, {[s] { return QVariant(s->additionalTrackers()); },
        [s](const QVariant &v) { s->setAdditionalTrackers(v.toString()); return QString(); }});
}
