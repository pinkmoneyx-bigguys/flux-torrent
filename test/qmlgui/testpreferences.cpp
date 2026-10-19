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

#include <memory>

#include <QCoreApplication>
#include <QObject>
#include <QTemporaryDir>
#include <QTest>

#include "base/global.h"
#include "base/path.h"
#include "base/preferences.h"
#include "base/profile.h"
#include "base/settingsstorage.h"

// Flux has no WebUI of its own to show: a fresh profile, or a migrated qBittorrent GUI profile that never
// enabled it, must not start listening on the network.
class TestPreferences final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestPreferences)

public:
    TestPreferences() = default;

private slots:
    void init()
    {
        m_dir = std::make_unique<QTemporaryDir>();
        QVERIFY(m_dir->isValid());
        Profile::initInstance(Path(m_dir->path() + u"/profile"_s), QString(), false);
        SettingsStorage::initInstance();
        Preferences::initInstance();
    }

    void cleanup()
    {
        Preferences::freeInstance();
        SettingsStorage::freeInstance();
        Profile::freeInstance();
        m_dir.reset();
    }

    void webUiIsOffByDefault() const
    {
#ifdef QBT_QML_GUI
        QVERIFY(!Preferences::instance()->isWebUIEnabled());
#else
        QSKIP("Upstream defaults apply to this build");
#endif
    }

    void explicitlyEnabledWebUiStaysEnabled() const
    {
        SettingsStorage::instance()->storeValue(u"Preferences/WebUI/Enabled"_s, true);
        QVERIFY(Preferences::instance()->isWebUIEnabled());
    }

private:
    std::unique_ptr<QTemporaryDir> m_dir;
};

QTEST_GUILESS_MAIN(TestPreferences)
#include "testpreferences.moc"
