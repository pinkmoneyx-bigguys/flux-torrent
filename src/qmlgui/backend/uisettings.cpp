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

#include "uisettings.h"

#include "base/global.h"
#include "base/settingsstorage.h"

namespace
{
    const QString STYLE_KEY = u"Flux/Appearance/Style"_s;

    // Only the default look is offered now; a profile that chose Liquid Glass gets the default look
    QString normalizedStyle(const QString &)
    {
        return u"default"_s;
    }

    QString columnsKey(const QString &table)
    {
        return u"Flux/Layout/%1Columns"_s.arg(table);
    }
}

UiSettings::UiSettings(QObject *parent)
    : QObject(parent)
{
    const SettingsStorage *storage = SettingsStorage::instance();
    m_style = normalizedStyle(storage ? storage->loadValue<QString>(STYLE_KEY) : QString());
}

QString UiSettings::style() const
{
    return m_style;
}

void UiSettings::setStyle(const QString &style)
{
    const QString value = normalizedStyle(style);
    if (value == m_style)
        return;

    m_style = value;
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(STYLE_KEY, m_style);
    emit styleChanged();
}

QVariantMap UiSettings::columnWidths(const QString &table) const
{
    const SettingsStorage *storage = SettingsStorage::instance();
    const QVariantMap stored = storage ? storage->loadValue<QVariantMap>(columnsKey(table)) : m_columnWidths.value(table);
    // the INI file hands numbers back as strings
    QVariantMap widths;
    for (auto it = stored.cbegin(); it != stored.cend(); ++it)
    {
        bool ok = false;
        const double width = it.value().toDouble(&ok);
        if (ok && (width > 0))
            widths.insert(it.key(), width);
    }
    return widths;
}

void UiSettings::setColumnWidths(const QString &table, const QVariantMap &widths)
{
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(columnsKey(table), widths);
    else
        m_columnWidths.insert(table, widths);
}

QVariant UiSettings::layoutValue(const QString &key, const QVariant &defaultValue) const
{
    const SettingsStorage *storage = SettingsStorage::instance();
    QVariant value = storage ? storage->loadValue<QVariant>(u"Flux/Layout/"_s + key, defaultValue)
                             : m_layout.value(key, defaultValue);
    if (defaultValue.isValid() && value.canConvert(defaultValue.metaType()))
        value.convert(defaultValue.metaType());
    return value;
}

void UiSettings::setLayoutValue(const QString &key, const QVariant &value)
{
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(u"Flux/Layout/"_s + key, value);
    else
        m_layout.insert(key, value);
}
