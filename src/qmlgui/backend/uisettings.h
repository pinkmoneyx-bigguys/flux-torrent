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

#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// Appearance choices of the Flux UI, kept in the profile (Flux.ini, "Flux/Appearance/...").
// Without a SettingsStorage (QML tests) the values live only in memory.
class UiSettings : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(UiSettings)
    QML_ELEMENT
    QML_SINGLETON

    // "default" (the shadcn-style look) or "glass" (Liquid Glass); anything else reads as "default"
    Q_PROPERTY(QString style READ style WRITE setStyle NOTIFY styleChanged FINAL)

public:
    explicit UiSettings(QObject *parent = nullptr);

    QString style() const;
    void setStyle(const QString &style);

    // Column widths a table remembers, {columnKey: pixels} ("Flux/Layout/<table>Columns"); {} when never set
    Q_INVOKABLE QVariantMap columnWidths(const QString &table) const;
    Q_INVOKABLE void setColumnWidths(const QString &table, const QVariantMap &widths);

    // Other layout choices ("Flux/Layout/<key>"): sidebar collapsed, details pane height...
    // The INI file hands values back as strings: the result takes the type of the default.
    Q_INVOKABLE QVariant layoutValue(const QString &key, const QVariant &defaultValue) const;
    Q_INVOKABLE void setLayoutValue(const QString &key, const QVariant &value);

signals:
    void styleChanged();

private:
    QString m_style;
    // without a SettingsStorage (tests)
    QHash<QString, QVariantMap> m_columnWidths;
    QVariantMap m_layout;
};
