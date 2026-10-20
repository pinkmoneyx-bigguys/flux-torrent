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
#include <QString>
#include <QTranslator>

class QLocale;
class QQmlApplicationEngine;

class FluxShell final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(FluxShell)

public:
    // `module` / `type` name the root QML component; they are parameters only so that a failed load can be tested
    explicit FluxShell(QObject *parent = nullptr, const QString &module = QStringLiteral("Flux"), const QString &type = QStringLiteral("Main"));
    ~FluxShell() override;

    // Loads the UI. Returns false if the root component could not be created: there is then no window
    bool show();
    void activate();

    QQmlApplicationEngine *engine() const;

    // Loads the embedded Flux UI translation (:/i18n/flux_<lang>.qm) that best matches `locale`
    static bool loadTranslation(QTranslator &translator, const QLocale &locale);

signals:
    // the language was changed: the application reloads Qt's and qBittorrent's translations (connected
    // directly, so they are in place before Flux's own and the new window)
    void reloadTranslationsRequested();

private:
    // Switches to Languages::effective(): translators, number and date formats, then the window again
    void switchLanguage();
    // Replaces the main window with a fresh one in the same place, on the same page
    void reloadMain();

    QTranslator m_translator;
    QQmlApplicationEngine *m_engine = nullptr;
    QString m_module;
    QString m_type;
};
