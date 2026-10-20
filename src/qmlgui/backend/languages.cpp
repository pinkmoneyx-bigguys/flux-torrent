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

#include "languages.h"

#include <QCoreApplication>
#include <QHash>
#include <QJSEngine>

#include "base/global.h"
#include "base/settingsstorage.h"

namespace
{
    // qBittorrent's own key: a language chosen there carries over to Flux
    const QString LOCALE_KEY = u"Preferences/General/Locale"_s;

    // without a profile (tests)
    QString g_choice;
}

Languages::Languages(QObject *parent)
    : QObject(parent)
{
}

Languages *Languages::instance()
{
    static Languages *languages = new Languages(QCoreApplication::instance());
    return languages;
}

Languages *Languages::create(QQmlEngine *, QJSEngine *)
{
    Languages *languages = instance();
    QJSEngine::setObjectOwnership(languages, QJSEngine::CppOwnership);
    return languages;
}

QStringList Languages::supported()
{
    return {u"en"_s, u"ru"_s, u"uk"_s, u"de"_s, u"es"_s, u"fr"_s, u"pt_BR"_s, u"pl"_s, u"zh_CN"_s};
}

QString Languages::nativeName(const QString &code)
{
    // written out: QLocale gives some in lower case ("русский") or with the country ("中文（中国）")
    static const QHash<QString, QString> names {
        {u"en"_s, u"English"_s},
        {u"ru"_s, u"Русский"_s},
        {u"uk"_s, u"Українська"_s},
        {u"de"_s, u"Deutsch"_s},
        {u"es"_s, u"Español"_s},
        {u"fr"_s, u"Français"_s},
        {u"pt_BR"_s, u"Português (Brasil)"_s},
        {u"pl"_s, u"Polski"_s},
        {u"zh_CN"_s, u"简体中文"_s},
    };
    return names.value(code, code);
}

QString Languages::resolve(const QString &choice, const QStringList &uiLanguages)
{
    const QStringList codes = supported();
    if (codes.contains(choice))
        return choice;

    for (const QString &wanted : uiLanguages)
    {
        const QLocale locale {wanted};
        // Chinese: only the simplified script is translated
        if (locale.language() == QLocale::Chinese)
        {
            if ((locale.script() == QLocale::SimplifiedChineseScript)
                || ((locale.script() == QLocale::AnyScript) && (locale.territory() != QLocale::Taiwan)
                    && (locale.territory() != QLocale::HongKong) && (locale.territory() != QLocale::Macao)))
            {
                return u"zh_CN"_s;
            }
            continue;
        }
        // Portuguese: the Brazilian translation reads well enough in Portugal too
        if (locale.language() == QLocale::Portuguese)
            return u"pt_BR"_s;
        for (const QString &code : codes)
        {
            if (QLocale(code).language() == locale.language())
                return code;
        }
    }
    return u"en"_s;
}

QString Languages::storedChoice()
{
    const SettingsStorage *storage = SettingsStorage::instance();
    return storage ? storage->loadValue<QString>(LOCALE_KEY) : g_choice;
}

QString Languages::effective()
{
    return resolve(storedChoice(), QLocale::system().uiLanguages());
}

QLocale Languages::effectiveLocale()
{
    // the system's formats when its language is the one shown (a Russian UI in Kazakhstan keeps
    // Kazakh dates); the language's own formats otherwise
    const QString code = effective();
    const QLocale system = QLocale::system();
    if (resolve({}, {system.name()}) == code)
        return system;
    return QLocale(code);
}

void Languages::store(const QString &choice)
{
    if (SettingsStorage *storage = SettingsStorage::instance())
        storage->storeValue(LOCALE_KEY, choice);
    else
        g_choice = choice;
}

QVariantList Languages::options() const
{
    QVariantList list;
    const QString system = resolve({}, QLocale::system().uiLanguages());
    list.append(QVariantMap {{u"key"_s, QString()}, {u"label"_s, tr("System (%1)").arg(nativeName(system))}});
    for (const QString &code : supported())
        list.append(QVariantMap {{u"key"_s, code}, {u"label"_s, nativeName(code)}});
    return list;
}

QString Languages::selected() const
{
    const QString choice = storedChoice();
    return supported().contains(choice) ? choice : QString();
}

QString Languages::current() const
{
    return effective();
}

void Languages::select(const QString &choice)
{
    const QString value = supported().contains(choice) ? choice : QString();
    if ((value == selected()) && (resolve(value, QLocale::system().uiLanguages()) == effective()))
        return;
    store(value);
    emit changed();
    emit switchRequested();
}
