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

#include <QLocale>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

// The UI language. The choice is kept where qBittorrent keeps its own (Preferences/General/Locale; ""
// follows the system), so one language covers Flux's strings (:/i18n/flux_<code>.qm), qBittorrent's
// (units, durations: :/lang/qbittorrent_<code>.qm), Qt's own and the number and date formats.
// A system language Flux has no translation for falls back to English, whole: no half-translated UI.
// select() asks for a switch; FluxShell carries it out (translators, then a fresh window).
class Languages : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Languages)
    QML_ELEMENT
    QML_SINGLETON

    // [{code, label}]: "" (the system's) first, then each language under its own name
    Q_PROPERTY(QVariantList options READ options NOTIFY changed FINAL)
    // what the user chose: "" for the system's, else a code of supported()
    Q_PROPERTY(QString selected READ selected NOTIFY changed FINAL)
    // the language in use
    Q_PROPERTY(QString current READ current NOTIFY changed FINAL)

public:
    static Languages *instance();
    static Languages *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    // The languages Flux is translated into ("en" is the source)
    static QStringList supported();
    // The language under its own name ("Deutsch", "Português (Brasil)")
    static QString nativeName(const QString &code);
    // The supported language for a choice: itself, or for "" the best match of `uiLanguages` (the
    // system's, most wanted first), else "en"
    static QString resolve(const QString &choice, const QStringList &uiLanguages);

    // The stored choice and what it resolves to on this system
    static QString storedChoice();
    static QString effective();
    static QLocale effectiveLocale();
    // Keeps a choice ("" or a supported code)
    static void store(const QString &choice);

    QVariantList options() const;
    QString selected() const;
    QString current() const;

    // Switches the UI to `choice` ("" for the system's language)
    Q_INVOKABLE void select(const QString &choice);

signals:
    void changed();
    // a new choice was stored: the UI should switch to effective()
    void switchRequested();

private:
    explicit Languages(QObject *parent = nullptr);
};
