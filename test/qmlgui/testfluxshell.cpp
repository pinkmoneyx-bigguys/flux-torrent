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

#include <QGuiApplication>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QTest>

#include "qmlgui/fluxshell.h"

// FluxShell::show() reports whether the root component was created. The application relies on it to leave
// instead of running on without a window. Only the failure path is exercised here: loading the real
// Flux.Main would open a window.
class TestFluxShell final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestFluxShell)

public:
    TestFluxShell() = default;

private slots:
    void missingTypeIsReportedAndCreatesNoWindow() const
    {
        FluxShell shell {nullptr, QStringLiteral("Flux"), QStringLiteral("NoSuchRootComponent")};

        QTest::ignoreMessage(QtCriticalMsg, QRegularExpression(QStringLiteral("Failed to load")));
        QVERIFY(!shell.show());
        QVERIFY(shell.engine()->rootObjects().isEmpty());
        QVERIFY(QGuiApplication::allWindows().isEmpty());
    }

    void missingModuleIsReported() const
    {
        FluxShell shell {nullptr, QStringLiteral("No.Such.Module"), QStringLiteral("Main")};

        QTest::ignoreMessage(QtCriticalMsg, QRegularExpression(QStringLiteral("Failed to load")));
        QVERIFY(!shell.show());
        QVERIFY(QGuiApplication::allWindows().isEmpty());
    }

    void loadedRootIsReportedAsSuccess() const
    {
        // A component that is no window, so nothing is shown
        FluxShell shell {nullptr, QStringLiteral("QtQml"), QStringLiteral("QtObject")};

        QVERIFY(shell.show());
        QCOMPARE(shell.engine()->rootObjects().size(), 1);
        // a second call keeps the existing root
        QVERIFY(shell.show());
        QCOMPARE(shell.engine()->rootObjects().size(), 1);
        QVERIFY(QGuiApplication::allWindows().isEmpty());
    }
};

int main(int argc, char *argv[])
{
    // No window may reach the user's screen, and no GPU is needed
    qputenv("QT_QPA_PLATFORM", "offscreen");
    qputenv("QT_QUICK_BACKEND", "software");
    QGuiApplication app {argc, argv};
    TestFluxShell test;
    return QTest::qExec(&test, argc, argv);
}

#include "testfluxshell.moc"
