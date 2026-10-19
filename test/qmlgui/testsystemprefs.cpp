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

#include <QObject>
#include <QOperatingSystemVersion>
#include <QSignalSpy>
#include <QTest>

#include "qmlgui/backend/systemprefs.h"

// The values depend on the machine's Windows settings, so only the contract is checked
class TestSystemPrefs final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestSystemPrefs)

public:
    TestSystemPrefs() = default;

private slots:
    void refreshIsStable() const
    {
        SystemPrefs prefs;
        const bool motion = prefs.reducedMotion();
        const bool transparency = prefs.reducedTransparency();

        QSignalSpy spy {&prefs, &SystemPrefs::changed};
        prefs.refresh();
        // the settings did not change between the two reads
        QCOMPARE(prefs.reducedMotion(), motion);
        QCOMPARE(prefs.reducedTransparency(), transparency);
        QCOMPARE(spy.count(), 0);
    }

    void windowsBuild() const
    {
        const SystemPrefs prefs;
#ifdef Q_OS_WIN
        // Windows 10 and 11 report major version 10; the build number tells them apart (11 = 22000+)
        QCOMPARE(prefs.windowsBuild(), QOperatingSystemVersion::current().microVersion());
        QVERIFY(prefs.windowsBuild() >= 10240);
#else
        QCOMPARE(prefs.windowsBuild(), 0);
#endif
    }
};

QTEST_APPLESS_MAIN(TestSystemPrefs)
#include "testsystemprefs.moc"
