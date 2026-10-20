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

#include <functional>

#include <QHash>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

// The application settings the Settings page edits, by key, applied at once. Each key maps onto
// BitTorrent::Session, Net::PortForwarder or Net::ProxyConfigurationManager; without a session (tests)
// the values live in memory with the same defaults. Speeds are in KiB/s (0 = unlimited), counts use
// -1 for unlimited, enumerations are strings (see the key list in appsettings.cpp).
class AppSettings : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(AppSettings)
    QML_ELEMENT
    QML_SINGLETON

    // Bumps on every change, so QML bindings can depend on "the settings"
    Q_PROPERTY(int revision READ revision NOTIFY changed FINAL)

public:
    explicit AppSettings(QObject *parent = nullptr);

    static AppSettings *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    int revision() const;

    Q_INVOKABLE QVariant value(const QString &key) const;
    // Returns "" or why the value was refused
    Q_INVOKABLE QString setValue(const QString &key, const QVariant &value);
    Q_INVOKABLE QStringList keys() const;
    // A free port for "Random"
    Q_INVOKABLE int randomPort() const;

signals:
    void changed(const QString &key);

private:
    struct Entry
    {
        std::function<QVariant ()> get;
        std::function<QString (const QVariant &)> set; // "" or the error
    };

    void registerLive();
    void registerMemory();

    QHash<QString, Entry> m_entries;
    QVariantMap m_memory;
    int m_revision = 0;
    double m_lastRatio = 2.0;
    int m_lastSeedMinutes = 1440;
};
