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

#include <QLocale>
#include <QObject>
#include <QTest>

#include "base/global.h"
#include "base/types.h"
#include "base/utils/misc.h"
#include "qmlgui/backend/format.h"

class TestFormat final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestFormat)

public:
    TestFormat() = default;

private slots:
    void speedZeroIsDash() const
    {
        QCOMPARE(Format().speed(0), u"—"_s);
    }

    void speedDelegates() const
    {
        // Compare against friendlyUnit itself: the decimal separator depends on the system locale.
        QCOMPARE(Format().speed(54'946'406), Utils::Misc::friendlyUnit(54'946'406, true));
    }

    void sizeDelegates() const
    {
        QCOMPARE(Format().size(0), Utils::Misc::friendlyUnit(0));
        QCOMPARE(Format().size(1'500'000'000), Utils::Misc::friendlyUnit(1'500'000'000));
    }

    void sizeNegativeIsDash() const
    {
        QCOMPARE(Format().size(-1), u"—"_s);
    }

    void etaInfinite() const
    {
        QCOMPARE(Format().eta(MAX_ETA), u"∞"_s);
        QCOMPARE(Format().eta(-5), u"∞"_s);
    }

    void etaDelegates() const
    {
        QCOMPARE(Format().eta(MAX_ETA - 1), Utils::Misc::userFriendlyDuration(MAX_ETA - 1));
        QCOMPARE(Format().eta(3600), Utils::Misc::userFriendlyDuration(3600));
    }

    void ratioTwoDigits() const
    {
        // Same locale as speed/size, so the UI shows consistent separators
        QCOMPARE(Format().ratio(3.125), QLocale::system().toString(3.125, 'f', 2));
        QCOMPARE(Format().ratio(0), QLocale::system().toString(0.0, 'f', 2));
    }

    void ratioInfinite() const
    {
        QCOMPARE(Format().ratio(-1), u"∞"_s);
        QCOMPARE(Format().ratio(10000), u"∞"_s);
    }
};

QTEST_APPLESS_MAIN(TestFormat)
#include "testformat.moc"
