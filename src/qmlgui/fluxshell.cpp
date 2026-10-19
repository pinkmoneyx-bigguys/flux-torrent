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

#include "fluxshell.h"

#include <QCoreApplication>
#include <QDebug>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <Qt>

#include <QWKQuick/qwkquickglobal.h>

#include "base/global.h"

FluxShell::FluxShell(QObject *parent)
    : QObject(parent)
{
    // Installed before the engine exists, so the first load of the QML already sees it
    if (loadTranslation(m_translator, QLocale::system()))
        QCoreApplication::installTranslator(&m_translator);

    m_engine = new QQmlApplicationEngine(this);
    // QML type WindowAgent (import QWindowKit) used by Main.qml
    QWK::registerTypes(m_engine);
}

FluxShell::~FluxShell()
{
    // Tear the UI down while the translator is still installed: removing it retranslates live QML
    delete m_engine;
    m_engine = nullptr;
}

bool FluxShell::loadTranslation(QTranslator &translator, const QLocale &locale)
{
    return translator.load(locale, u"flux"_s, u"_"_s, u":/i18n"_s);
}

void FluxShell::show()
{
    if (!m_engine->rootObjects().isEmpty())
        return;

    m_engine->loadFromModule(u"Flux"_s, u"Main"_s);
    if (m_engine->rootObjects().isEmpty())
        qCritical("Failed to load the Flux.Main QML component.");
}

void FluxShell::activate()
{
    const auto rootObjects = m_engine->rootObjects();
    for (QObject *object : rootObjects)
    {
        auto *window = qobject_cast<QQuickWindow *>(object);
        if (!window)
            continue;

        // Un-minimize into the previous state, so a maximized window comes back maximized
        if (window->windowStates() & Qt::WindowMinimized)
            window->setWindowStates(window->windowStates() & ~Qt::WindowMinimized);
        window->show();

        window->raise();
        window->requestActivate();
    }
}

QQmlApplicationEngine *FluxShell::engine() const
{
    return m_engine;
}
