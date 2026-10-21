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

#include <QCoreApplication>
#include <QRandomGenerator>
#include <QTime>

#include "base/bittorrent/session.h"
#include "base/bittorrent/sharelimits.h"
#include "base/bittorrent/torrent.h"
#include "base/bittorrent/torrentcontentlayout.h"
#include "base/global.h"
#include "base/net/portforwarder.h"
#include "base/net/proxyconfigurationmanager.h"
#include "base/path.h"
#include "base/preferences.h"
#include "base/settingsstorage.h"

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
            {u"dblClickRunning"_s, u"toggle"_s},
            {u"dblClickFinished"_s, u"open"_s},
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
            {u"additionalTrackers"_s, QString()},
            // Watching (Flux's own, kept in the profile)
            {u"afterWatching"_s, u"ask"_s},
            {u"hardwareDecoding"_s, true},
            // Notification area (qBittorrent's own keys, so a moved profile keeps them)
            {u"trayEnabled"_s, true},
            {u"closeToTray"_s, true},
            {u"minimizeToTray"_s, false},
            {u"notifyFinished"_s, true}
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
            {u"dblClickRunning"_s, {{u"toggle"_s, 0}, {u"open"_s, 1}, {u"none"_s, 3}}},
            {u"dblClickFinished"_s, {{u"open"_s, 1}, {u"toggle"_s, 0}, {u"none"_s, 3}}},
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

    // --- Advanced -------------------------------------------------------------------------------
    struct AdvancedSpec
    {
        QString key;
        const char *group;
        const char *label;
        QString type;                 // "int", "bool", "string", "enum"
        QVariant def;
        int min = 0;
        int max = 0;
        const char *unit = "";
        QList<std::pair<QString, int>> options; // enum: key -> core value
        bool restart = false;
    };


    const QList<AdvancedSpec> &advancedSpecs()
    {
        static const QList<AdvancedSpec> specs {
            // Disk
            {u"asyncIOThreads"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Asynchronous I/O threads"), u"int"_s, 10, 1, 1024},
            {u"hashingThreads"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Hashing threads"), u"int"_s, 1, 1, 1024},
            {u"filePoolSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "File pool size"), u"int"_s, 100, 1, 100000},
            {u"checkingMemUsage"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Memory for checking torrents"), u"int"_s, 32, 1, 1024, "MiB"},
            {u"diskQueueSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Disk queue size"), u"int"_s, 1024, 1, 1048576, "KiB"},
            {u"diskIOType"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Disk I/O type"), u"enum"_s, u"default"_s, 0, 0, "",
                {{u"default"_s, int(BitTorrent::DiskIOType::Default)}, {u"mmap"_s, int(BitTorrent::DiskIOType::MMap)},
                 {u"posix"_s, int(BitTorrent::DiskIOType::Posix)}, {u"simple"_s, int(BitTorrent::DiskIOType::SimplePreadPwrite)}}, true},
            {u"diskIOReadMode"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Disk read mode"), u"enum"_s, u"osCache"_s, 0, 0, "",
                {{u"noOsCache"_s, int(BitTorrent::DiskIOReadMode::DisableOSCache)}, {u"osCache"_s, int(BitTorrent::DiskIOReadMode::EnableOSCache)}}},
            {u"diskIOWriteMode"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Disk write mode"), u"enum"_s, u"osCache"_s, 0, 0, "",
                {{u"noOsCache"_s, int(BitTorrent::DiskIOWriteMode::DisableOSCache)}, {u"osCache"_s, int(BitTorrent::DiskIOWriteMode::EnableOSCache)},
                 {u"writeThrough"_s, int(BitTorrent::DiskIOWriteMode::WriteThrough)}}},
            {u"coalesceReadWrite"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Coalesce reads and writes"), u"bool"_s, true},
            {u"pieceExtentAffinity"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Piece extent affinity"), u"bool"_s, false},
            {u"suggestMode"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Send upload piece suggestions"), u"bool"_s, false},
            {u"saveResumeDataInterval"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Save resume data every"), u"int"_s, 60, 0, 1440, "min"},
            {u"maxActiveChecking"_s, QT_TRANSLATE_NOOP("AppSettings", "Disk"), QT_TRANSLATE_NOOP("AppSettings", "Torrents checked at once"), u"int"_s, 1, -1, 1000},
            // Network
            {u"sendBufferWatermark"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Send buffer watermark"), u"int"_s, 500, 1, 1048576, "KiB"},
            {u"sendBufferLowWatermark"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Send buffer low watermark"), u"int"_s, 10, 1, 1048576, "KiB"},
            {u"sendBufferWatermarkFactor"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Send buffer watermark factor"), u"int"_s, 50, 1, 1000, "%"},
            {u"connectionSpeed"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Outgoing connections per second"), u"int"_s, 30, 0, 1000},
            {u"socketSendBufferSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Socket send buffer (0: system default)"), u"int"_s, 0, 0, 1048576, "KiB"},
            {u"socketReceiveBufferSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Socket receive buffer (0: system default)"), u"int"_s, 0, 0, 1048576, "KiB"},
            {u"socketBacklogSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Socket backlog size"), u"int"_s, 30, 1, 100000},
            {u"outgoingPortsMin"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Outgoing ports from (0: any)"), u"int"_s, 0, 0, 65535},
            {u"outgoingPortsMax"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Outgoing ports to (0: any)"), u"int"_s, 0, 0, 65535},
            {u"upnpLeaseDuration"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "UPnP lease duration (0: permanent)"), u"int"_s, 0, 0, 1000000, "s"},
            {u"peerDSCP"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Type of service (DSCP) for peer connections"), u"int"_s, 1, 0, 63},
            {u"utpMixedMode"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "TCP and µTP mixed mode"), u"enum"_s, u"preferTcp"_s, 0, 0, "",
                {{u"preferTcp"_s, int(BitTorrent::MixedModeAlgorithm::TCP)}, {u"proportional"_s, int(BitTorrent::MixedModeAlgorithm::Proportional)}}},
            {u"idnSupport"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Internationalized domain names"), u"bool"_s, false},
            {u"multiConnectionsPerIp"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Several connections from one IP"), u"bool"_s, false},
            {u"validateHttpsTrackers"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Validate HTTPS tracker certificates"), u"bool"_s, true},
            {u"ssrfMitigation"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Server-side request forgery mitigation"), u"bool"_s, true},
            {u"blockPrivilegedPorts"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Block peers on privileged ports"), u"bool"_s, false},
            {u"hostnameCacheTTL"_s, QT_TRANSLATE_NOOP("AppSettings", "Network"), QT_TRANSLATE_NOOP("AppSettings", "Host name cache lifetime"), u"int"_s, 1200, 0, 1000000, "s"},
            // Peers
            {u"chokingAlgorithm"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Upload slots behavior"), u"enum"_s, u"fixedSlots"_s, 0, 0, "",
                {{u"fixedSlots"_s, int(BitTorrent::ChokingAlgorithm::FixedSlots)}, {u"rateBased"_s, int(BitTorrent::ChokingAlgorithm::RateBased)}}},
            {u"seedChokingAlgorithm"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Upload choking algorithm"), u"enum"_s, u"fastestUpload"_s, 0, 0, "",
                {{u"roundRobin"_s, int(BitTorrent::SeedChokingAlgorithm::RoundRobin)}, {u"fastestUpload"_s, int(BitTorrent::SeedChokingAlgorithm::FastestUpload)},
                 {u"antiLeech"_s, int(BitTorrent::SeedChokingAlgorithm::AntiLeech)}}},
            {u"peerTurnover"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Peer turnover"), u"int"_s, 4, 0, 100, "%"},
            {u"peerTurnoverCutoff"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Peer turnover threshold"), u"int"_s, 90, 0, 100, "%"},
            {u"peerTurnoverInterval"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Peer turnover interval"), u"int"_s, 300, 0, 3600, "s"},
            {u"requestQueueSize"_s, QT_TRANSLATE_NOOP("AppSettings", "Peers"), QT_TRANSLATE_NOOP("AppSettings", "Outstanding requests per peer"), u"int"_s, 500, 1, 100000},
            // Trackers
            {u"announceToAllTrackers"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Announce to all trackers in a tier"), u"bool"_s, false},
            {u"announceToAllTiers"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Announce to all tiers"), u"bool"_s, true},
            {u"announceIP"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "IP address reported to trackers"), u"string"_s, QString()},
            {u"announcePort"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Port reported to trackers (0: listening port)"), u"int"_s, 0, 0, 65535},
            {u"maxConcurrentHTTPAnnounces"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Concurrent HTTP announces"), u"int"_s, 50, 1, 1000},
            {u"stopTrackerTimeout"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Stop tracker timeout"), u"int"_s, 2, 0, 600, "s"},
            {u"reannounceOnAddressChange"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "Reannounce when the IP or port changes"), u"bool"_s, false},
            {u"dhtBootstrapNodes"_s, QT_TRANSLATE_NOOP("AppSettings", "Trackers"), QT_TRANSLATE_NOOP("AppSettings", "DHT bootstrap nodes"), u"string"_s,
                u"dht.libtorrent.org:25401, dht.transmissionbt.com:6881, router.bittorrent.com:6881"_s},
        };
        return specs;
    }

    const AdvancedSpec *advancedSpec(const QString &key)
    {
        for (const AdvancedSpec &spec : advancedSpecs())
        {
            if (spec.key == key)
                return &spec;
        }
        return nullptr;
    }

    QString checkAdvanced(const AdvancedSpec &spec, const QVariant &v)
    {
        if (spec.type == u"int")
            return checkRange(v, spec.min, spec.max);
        if (spec.type == u"enum")
        {
            for (const auto &option : spec.options)
            {
                if (option.first == v.toString())
                    return {};
            }
            return QObject::tr("Unknown option.");
        }
        return {};
    }

    int advancedEnumValue(const AdvancedSpec &spec, const QString &name)
    {
        for (const auto &option : spec.options)
        {
            if (option.first == name)
                return option.second;
        }
        return 0;
    }

    QString advancedEnumName(const AdvancedSpec &spec, const int value)
    {
        for (const auto &option : spec.options)
        {
            if (option.second == value)
                return option.first;
        }
        return spec.def.toString();
    }

    // Scheduler: days as strings, times as "HH:mm"
    const QList<std::pair<QString, Scheduler::Days>> &schedulerDayNames()
    {
        static const QList<std::pair<QString, Scheduler::Days>> names {
            {u"everyDay"_s, Scheduler::Days::EveryDay}, {u"weekday"_s, Scheduler::Days::Weekday}, {u"weekend"_s, Scheduler::Days::Weekend},
            {u"monday"_s, Scheduler::Days::Monday}, {u"tuesday"_s, Scheduler::Days::Tuesday}, {u"wednesday"_s, Scheduler::Days::Wednesday},
            {u"thursday"_s, Scheduler::Days::Thursday}, {u"friday"_s, Scheduler::Days::Friday}, {u"saturday"_s, Scheduler::Days::Saturday},
            {u"sunday"_s, Scheduler::Days::Sunday}
        };
        return names;
    }

    QString checkTime(const QVariant &v)
    {
        return QTime::fromString(v.toString(), u"HH:mm"_s).isValid() ? QString() : QObject::tr("Enter a time as HH:MM.");
    }

    const QVariantMap &allDefaults()
    {
        static const QVariantMap map = []
        {
            QVariantMap m = defaults();
            m.insert(u"schedulerFrom"_s, u"08:00"_s);
            m.insert(u"schedulerTo"_s, u"20:00"_s);
            m.insert(u"schedulerDays"_s, u"everyDay"_s);
            for (const AdvancedSpec &spec : advancedSpecs())
                m.insert(spec.key, spec.def);
            return m;
        }();
        return map;
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
    return allDefaults().keys();
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
    m_memory = allDefaults();
    for (const QString &key : allDefaults().keys())
    {
        m_entries.insert(key, {
            [this, key] { return m_memory.value(key); },
            [this, key](const QVariant &v) -> QString
            {
                const QVariant def = allDefaults().value(key);
                if (const AdvancedSpec *spec = advancedSpec(key))
                {
                    if (const QString e = checkAdvanced(*spec, v); !e.isEmpty())
                        return e;
                }
                else if ((key == u"schedulerFrom") || (key == u"schedulerTo"))
                {
                    if (const QString e = checkTime(v); !e.isEmpty())
                        return e;
                }
                else if (key == u"schedulerDays")
                {
                    const bool known = std::any_of(schedulerDayNames().cbegin(), schedulerDayNames().cend(),
                        [&v](const auto &day) { return day.first == v.toString(); });
                    if (!known)
                        return tr("Unknown option.");
                }
                else if (!enumValues(key).isEmpty())
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
    // double-click on a torrent, as qBittorrent keeps it
    Preferences *prefs = Preferences::instance();
    enumEntry(u"dblClickRunning"_s, [prefs] { return prefs->getActionOnDblClOnTorrentDl(); },
        [prefs](int v) { prefs->setActionOnDblClOnTorrentDl(v); });
    enumEntry(u"dblClickFinished"_s, [prefs] { return prefs->getActionOnDblClOnTorrentFn(); },
        [prefs](int v) { prefs->setActionOnDblClOnTorrentFn(v); });
    enumEntry(u"shareAction"_s, [s] { return int(s->shareLimitAction()); },
        [s](int v) { s->setShareLimitAction(static_cast<BitTorrent::ShareLimitAction>(v)); });
    boolEntry(u"addTrackersEnabled"_s, [s] { return s->isAddTrackersEnabled(); }, [s](bool b) { s->setAddTrackersEnabled(b); });
    m_entries.insert(u"additionalTrackers"_s, {[s] { return QVariant(s->additionalTrackers()); },
        [s](const QVariant &v) { s->setAdditionalTrackers(v.toString()); return QString(); }});

    registerAdvancedLive();

    // Watching: Flux's own values in the profile
    const auto storedEntry = [this](const QString &key, const QString &storageKey, const QVariant &def, const QStringList &allowed)
    {
        m_entries.insert(key, {
            [storageKey, def]
            {
                const SettingsStorage *storage = SettingsStorage::instance();
                QVariant value = storage ? storage->loadValue<QVariant>(storageKey, def) : def;
                // the INI file hands back strings ("true"): give QML the default's type
                value.convert(def.metaType());
                return value;
            },
            [storageKey, def, allowed](const QVariant &v) -> QString
            {
                if (!allowed.isEmpty() && !allowed.contains(v.toString()))
                    return tr("Unknown option.");
                QVariant value = v;
                value.convert(def.metaType());
                if (SettingsStorage *storage = SettingsStorage::instance())
                    storage->storeValue(storageKey, value);
                return {};
            }});
    };
    storedEntry(u"afterWatching"_s, u"Flux/Player/AfterWatching"_s, u"ask"_s, {u"ask"_s, u"keep"_s, u"delete"_s});
    storedEntry(u"hardwareDecoding"_s, u"Flux/Player/HardwareDecoding"_s, true, {});

    // Notification area
    boolEntry(u"trayEnabled"_s, [prefs] { return prefs->systemTrayEnabled(); }, [prefs](bool b) { prefs->setSystemTrayEnabled(b); });
    boolEntry(u"closeToTray"_s, [prefs] { return prefs->closeToTray(); }, [prefs](bool b) { prefs->setCloseToTray(b); });
    boolEntry(u"minimizeToTray"_s, [prefs] { return prefs->minimizeToTray(); }, [prefs](bool b) { prefs->setMinimizeToTray(b); });
    storedEntry(u"notifyFinished"_s, u"Flux/Notifications/DownloadFinished"_s, true, {});
}

QVariantList AppSettings::advancedSettings() const
{
    QVariantList list;
    for (const AdvancedSpec &spec : advancedSpecs())
    {
        QVariantList options;
        for (const auto &option : spec.options)
            options.append(QVariantMap {{u"key"_s, option.first}, {u"label"_s, option.first}});
        list.append(QVariantMap {
            {u"key"_s, spec.key},
            {u"group"_s, QCoreApplication::translate("AppSettings", spec.group)},
            {u"label"_s, QCoreApplication::translate("AppSettings", spec.label)},
            {u"type"_s, spec.type},
            {u"options"_s, options},
            {u"min"_s, spec.min},
            {u"max"_s, spec.max},
            {u"unit"_s, QString::fromLatin1(spec.unit)},
            {u"default"_s, spec.def},
            {u"restart"_s, spec.restart}
        });
    }
    return list;
}

QString AppSettings::resetValue(const QString &key)
{
    if (!allDefaults().contains(key))
        return tr("Unknown setting.");
    return setValue(key, allDefaults().value(key));
}

void AppSettings::resetAdvanced()
{
    for (const AdvancedSpec &spec : advancedSpecs())
        setValue(spec.key, spec.def);
}

void AppSettings::registerAdvancedLive()
{
    Session *s = Session::instance();

    // getter/setter in the core's units; `scale` converts KiB shown to bytes stored
    const auto intEntry = [this](const QString &key, std::function<qint64 ()> get, std::function<void (qint64)> set, const int scale = 1)
    {
        const AdvancedSpec *spec = advancedSpec(key);
        m_entries.insert(key, {
            [get, scale] { return QVariant(static_cast<int>(get() / scale)); },
            [spec, set, scale](const QVariant &v) -> QString
            {
                if (const QString e = checkAdvanced(*spec, v); !e.isEmpty())
                    return e;
                set(static_cast<qint64>(v.toInt()) * scale);
                return {};
            }});
    };
    const auto boolEntry = [this](const QString &key, std::function<bool ()> get, std::function<void (bool)> set)
    {
        m_entries.insert(key, {[get] { return QVariant(get()); }, [set](const QVariant &v) { set(v.toBool()); return QString(); }});
    };
    const auto enumEntry = [this](const QString &key, std::function<int ()> get, std::function<void (int)> set)
    {
        const AdvancedSpec *spec = advancedSpec(key);
        m_entries.insert(key, {
            [spec, get] { return QVariant(advancedEnumName(*spec, get())); },
            [spec, set](const QVariant &v) -> QString
            {
                if (const QString e = checkAdvanced(*spec, v); !e.isEmpty())
                    return e;
                set(advancedEnumValue(*spec, v.toString()));
                return {};
            }});
    };
    const auto stringEntry = [this](const QString &key, std::function<QString ()> get, std::function<void (const QString &)> set)
    {
        m_entries.insert(key, {[get] { return QVariant(get()); }, [set](const QVariant &v) { set(v.toString().trimmed()); return QString(); }});
    };

    using namespace BitTorrent;
    intEntry(u"asyncIOThreads"_s, [s] { return s->asyncIOThreads(); }, [s](qint64 v) { s->setAsyncIOThreads(int(v)); });
    intEntry(u"hashingThreads"_s, [s] { return s->hashingThreads(); }, [s](qint64 v) { s->setHashingThreads(int(v)); });
    intEntry(u"filePoolSize"_s, [s] { return s->filePoolSize(); }, [s](qint64 v) { s->setFilePoolSize(int(v)); });
    intEntry(u"checkingMemUsage"_s, [s] { return s->checkingMemUsage(); }, [s](qint64 v) { s->setCheckingMemUsage(int(v)); });
    intEntry(u"diskQueueSize"_s, [s] { return s->diskQueueSize(); }, [s](qint64 v) { s->setDiskQueueSize(v); }, 1024);
    enumEntry(u"diskIOType"_s, [s] { return int(s->diskIOType()); }, [s](int v) { s->setDiskIOType(static_cast<DiskIOType>(v)); });
    enumEntry(u"diskIOReadMode"_s, [s] { return int(s->diskIOReadMode()); }, [s](int v) { s->setDiskIOReadMode(static_cast<DiskIOReadMode>(v)); });
    enumEntry(u"diskIOWriteMode"_s, [s] { return int(s->diskIOWriteMode()); }, [s](int v) { s->setDiskIOWriteMode(static_cast<DiskIOWriteMode>(v)); });
    boolEntry(u"coalesceReadWrite"_s, [s] { return s->isCoalesceReadWriteEnabled(); }, [s](bool b) { s->setCoalesceReadWriteEnabled(b); });
    boolEntry(u"pieceExtentAffinity"_s, [s] { return s->usePieceExtentAffinity(); }, [s](bool b) { s->setPieceExtentAffinity(b); });
    boolEntry(u"suggestMode"_s, [s] { return s->isSuggestModeEnabled(); }, [s](bool b) { s->setSuggestMode(b); });
    intEntry(u"saveResumeDataInterval"_s, [s] { return s->saveResumeDataInterval(); }, [s](qint64 v) { s->setSaveResumeDataInterval(int(v)); });
    intEntry(u"maxActiveChecking"_s, [s] { return s->maxActiveCheckingTorrents(); }, [s](qint64 v) { s->setMaxActiveCheckingTorrents(int(v)); });

    intEntry(u"sendBufferWatermark"_s, [s] { return s->sendBufferWatermark(); }, [s](qint64 v) { s->setSendBufferWatermark(int(v)); });
    intEntry(u"sendBufferLowWatermark"_s, [s] { return s->sendBufferLowWatermark(); }, [s](qint64 v) { s->setSendBufferLowWatermark(int(v)); });
    intEntry(u"sendBufferWatermarkFactor"_s, [s] { return s->sendBufferWatermarkFactor(); }, [s](qint64 v) { s->setSendBufferWatermarkFactor(int(v)); });
    intEntry(u"connectionSpeed"_s, [s] { return s->connectionSpeed(); }, [s](qint64 v) { s->setConnectionSpeed(int(v)); });
    intEntry(u"socketSendBufferSize"_s, [s] { return s->socketSendBufferSize(); }, [s](qint64 v) { s->setSocketSendBufferSize(int(v)); }, 1024);
    intEntry(u"socketReceiveBufferSize"_s, [s] { return s->socketReceiveBufferSize(); }, [s](qint64 v) { s->setSocketReceiveBufferSize(int(v)); }, 1024);
    intEntry(u"socketBacklogSize"_s, [s] { return s->socketBacklogSize(); }, [s](qint64 v) { s->setSocketBacklogSize(int(v)); });
    intEntry(u"outgoingPortsMin"_s, [s] { return s->outgoingPortsMin(); }, [s](qint64 v) { s->setOutgoingPortsMin(int(v)); });
    intEntry(u"outgoingPortsMax"_s, [s] { return s->outgoingPortsMax(); }, [s](qint64 v) { s->setOutgoingPortsMax(int(v)); });
    intEntry(u"upnpLeaseDuration"_s, [s] { return s->UPnPLeaseDuration(); }, [s](qint64 v) { s->setUPnPLeaseDuration(int(v)); });
    intEntry(u"peerDSCP"_s, [s] { return s->peerDSCP(); }, [s](qint64 v) { s->setPeerDSCP(int(v)); });
    enumEntry(u"utpMixedMode"_s, [s] { return int(s->utpMixedMode()); }, [s](int v) { s->setUtpMixedMode(static_cast<MixedModeAlgorithm>(v)); });
    boolEntry(u"idnSupport"_s, [s] { return s->isIDNSupportEnabled(); }, [s](bool b) { s->setIDNSupportEnabled(b); });
    boolEntry(u"multiConnectionsPerIp"_s, [s] { return s->multiConnectionsPerIpEnabled(); }, [s](bool b) { s->setMultiConnectionsPerIpEnabled(b); });
    boolEntry(u"validateHttpsTrackers"_s, [s] { return s->validateHTTPSTrackerCertificate(); }, [s](bool b) { s->setValidateHTTPSTrackerCertificate(b); });
    boolEntry(u"ssrfMitigation"_s, [s] { return s->isSSRFMitigationEnabled(); }, [s](bool b) { s->setSSRFMitigationEnabled(b); });
    boolEntry(u"blockPrivilegedPorts"_s, [s] { return s->blockPeersOnPrivilegedPorts(); }, [s](bool b) { s->setBlockPeersOnPrivilegedPorts(b); });
    intEntry(u"hostnameCacheTTL"_s, [s] { return s->hostnameCacheTTL(); }, [s](qint64 v) { s->setHostnameCacheTTL(int(v)); });

    enumEntry(u"chokingAlgorithm"_s, [s] { return int(s->chokingAlgorithm()); }, [s](int v) { s->setChokingAlgorithm(static_cast<ChokingAlgorithm>(v)); });
    enumEntry(u"seedChokingAlgorithm"_s, [s] { return int(s->seedChokingAlgorithm()); }, [s](int v) { s->setSeedChokingAlgorithm(static_cast<SeedChokingAlgorithm>(v)); });
    intEntry(u"peerTurnover"_s, [s] { return s->peerTurnover(); }, [s](qint64 v) { s->setPeerTurnover(int(v)); });
    intEntry(u"peerTurnoverCutoff"_s, [s] { return s->peerTurnoverCutoff(); }, [s](qint64 v) { s->setPeerTurnoverCutoff(int(v)); });
    intEntry(u"peerTurnoverInterval"_s, [s] { return s->peerTurnoverInterval(); }, [s](qint64 v) { s->setPeerTurnoverInterval(int(v)); });
    intEntry(u"requestQueueSize"_s, [s] { return s->requestQueueSize(); }, [s](qint64 v) { s->setRequestQueueSize(int(v)); });

    boolEntry(u"announceToAllTrackers"_s, [s] { return s->announceToAllTrackers(); }, [s](bool b) { s->setAnnounceToAllTrackers(b); });
    boolEntry(u"announceToAllTiers"_s, [s] { return s->announceToAllTiers(); }, [s](bool b) { s->setAnnounceToAllTiers(b); });
    stringEntry(u"announceIP"_s, [s] { return s->announceIP(); }, [s](const QString &v) { s->setAnnounceIP(v); });
    intEntry(u"announcePort"_s, [s] { return s->announcePort(); }, [s](qint64 v) { s->setAnnouncePort(int(v)); });
    intEntry(u"maxConcurrentHTTPAnnounces"_s, [s] { return s->maxConcurrentHTTPAnnounces(); }, [s](qint64 v) { s->setMaxConcurrentHTTPAnnounces(int(v)); });
    intEntry(u"stopTrackerTimeout"_s, [s] { return s->stopTrackerTimeout(); }, [s](qint64 v) { s->setStopTrackerTimeout(int(v)); });
    boolEntry(u"reannounceOnAddressChange"_s, [s] { return s->isReannounceWhenAddressChangedEnabled(); },
        [s](bool b) { s->setReannounceWhenAddressChangedEnabled(b); });
    stringEntry(u"dhtBootstrapNodes"_s, [s] { return s->getDHTBootstrapNodes(); }, [s](const QString &v) { s->setDHTBootstrapNodes(v); });

    // Alternative speed schedule (kept in Preferences; the session's scheduler reads it)
    m_entries.insert(u"schedulerFrom"_s, {
        [] { return QVariant(Preferences::instance()->getSchedulerStartTime().toString(u"HH:mm"_s)); },
        [](const QVariant &v) -> QString
        {
            if (const QString e = checkTime(v); !e.isEmpty())
                return e;
            Preferences::instance()->setSchedulerStartTime(QTime::fromString(v.toString(), u"HH:mm"_s));
            return {};
        }});
    m_entries.insert(u"schedulerTo"_s, {
        [] { return QVariant(Preferences::instance()->getSchedulerEndTime().toString(u"HH:mm"_s)); },
        [](const QVariant &v) -> QString
        {
            if (const QString e = checkTime(v); !e.isEmpty())
                return e;
            Preferences::instance()->setSchedulerEndTime(QTime::fromString(v.toString(), u"HH:mm"_s));
            return {};
        }});
    m_entries.insert(u"schedulerDays"_s, {
        []
        {
            const Scheduler::Days days = Preferences::instance()->getSchedulerDays();
            for (const auto &[name, value] : schedulerDayNames())
            {
                if (value == days)
                    return QVariant(name);
            }
            return QVariant(u"everyDay"_s);
        },
        [](const QVariant &v) -> QString
        {
            for (const auto &[name, value] : schedulerDayNames())
            {
                if (name == v.toString())
                {
                    Preferences::instance()->setSchedulerDays(value);
                    return {};
                }
            }
            return QObject::tr("Unknown option.");
        }});
}
