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

#include <QtCore/QCoreApplication>
#include <QtCore/QLocale>
#include <QtCore/QTranslator>
#include <QtQml>
#include <QtQuick/QQuickWindow>
#include <QtQuickTest>

#include <QWKQuick/qwkquickglobal.h>

#include "qmlgui/fluxshell.h"

// The Flux module is a static QML module: import its plugin so "import Flux" resolves in the tests
Q_IMPORT_QML_PLUGIN(FluxPlugin)

// Exposed to the tests as FluxTestI18n: switches the UI language the way the app picks it at start
// (FluxShell::loadTranslation) and retranslates the live QML
class I18nSwitcher : public QObject
{
    Q_OBJECT

public:
    explicit I18nSwitcher(QQmlEngine *engine)
        : QObject(engine)
        , m_engine {engine}
    {
    }

    ~I18nSwitcher() override
    {
        QCoreApplication::removeTranslator(&m_translator);
    }

    // "" restores the English source strings; returns false if no translation for `lang` is built in
    Q_INVOKABLE bool setLanguage(const QString &lang)
    {
        QCoreApplication::removeTranslator(&m_translator);
        bool ok = true;
        if (!lang.isEmpty())
        {
            ok = FluxShell::loadTranslation(m_translator, QLocale(lang));
            if (ok)
                QCoreApplication::installTranslator(&m_translator);
        }
        m_engine->retranslate();
        return ok;
    }

private:
    QQmlEngine *m_engine = nullptr;
    QTranslator m_translator;
};

class Setup : public QObject
{
    Q_OBJECT

public slots:
    void applicationAvailable()
    {
        // Render like the app does (src/app/main.cpp), so shader and grab tests see the same backend
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    }

    void qmlEngineAvailable(QQmlEngine *engine)
    {
        // Like FluxShell: Main.qml imports QWindowKit
        QWK::registerTypes(engine);
        engine->rootContext()->setContextProperty(QStringLiteral("FluxTestI18n"),new I18nSwitcher(engine));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(flux_qml, Setup)

#include "qmltests.moc"
