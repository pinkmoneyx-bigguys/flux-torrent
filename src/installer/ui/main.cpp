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

// FluxSetup: the setup's interface. The stub runs it from the unpacked files with --source; Flux's
// updater with --update --dir <folder> --pid <its process>; "Installed apps" with --uninstall.

#include <windows.h>
#include <objbase.h>

#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

#include <QWKQuick/qwkquickglobal.h>

#include "setup.h"

using namespace Qt::Literals::StringLiterals;

int main(int argc, char *argv[])
{
    ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    QGuiApplication app {argc, argv};
    QGuiApplication::setApplicationName(u"Flux Torrent setup"_s);

    Setup::Options options;
    const QStringList args = QGuiApplication::arguments();
    for (qsizetype i = 1; i < args.size(); ++i)
    {
        const QString &arg = args[i];
        const QString next = (i + 1 < args.size()) ? args[i + 1] : QString();
        if (arg == u"--uninstall")
            options.mode = u"uninstall"_s;
        else if (arg == u"--update")
            options.mode = u"update"_s;
        else if ((arg == u"--source") && !next.isEmpty())
            options.source = args[++i];
        else if ((arg == u"--dir") && !next.isEmpty())
            options.targetDir = args[++i];
        else if ((arg == u"--lang") && !next.isEmpty())
            options.language = args[++i];
        else if ((arg == u"--pid") && !next.isEmpty())
            options.fluxPid = args[++i].toLongLong();
    }
    Setup::configure(options);

    // the faces of Flux itself
    for (const QString &font : {u"Geist-Variable.ttf"_s, u"GeistMono-Variable.ttf"_s})
        QFontDatabase::addApplicationFont(u":/fluxsetup/fonts/"_s + font);

    QQmlApplicationEngine engine;
    QWK::registerTypes(&engine);
    engine.loadFromModule(u"FluxSetup"_s, u"Main"_s);
    if (engine.rootObjects().isEmpty())
        return 1;
    const int code = QGuiApplication::exec();
    ::CoUninitialize();
    return code;
}
