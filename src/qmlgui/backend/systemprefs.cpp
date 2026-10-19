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

#include "systemprefs.h"

#ifdef Q_OS_WIN
#include <QSettings>
#include <QString>
#include <QVariant>

#include <windows.h>

#include "base/global.h"
#endif

namespace
{
    bool systemReducedMotion()
    {
#ifdef Q_OS_WIN
        // "Animation effects" switch in Settings > Accessibility > Visual effects
        BOOL animationsEnabled = TRUE;
        if (::SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animationsEnabled, 0))
            return (animationsEnabled == FALSE);
#endif
        return false;
    }

    bool systemReducedTransparency()
    {
#ifdef Q_OS_WIN
        // "Transparency effects" switch; a missing value means the default (enabled)
        const QSettings personalize {u"HKEY_CURRENT_USER/Software/Microsoft/Windows/CurrentVersion/Themes/Personalize"_s
                , QSettings::NativeFormat};
        const QVariant value = personalize.value(u"EnableTransparency"_s);
        if (value.isValid())
            return (value.toInt() == 0);
#endif
        return false;
    }
}

SystemPrefs::SystemPrefs(QObject *parent)
    : QObject(parent)
    , m_reducedMotion {systemReducedMotion()}
    , m_reducedTransparency {systemReducedTransparency()}
{
}

bool SystemPrefs::reducedMotion() const
{
    return m_reducedMotion;
}

bool SystemPrefs::reducedTransparency() const
{
    return m_reducedTransparency;
}

void SystemPrefs::refresh()
{
    const bool motion = systemReducedMotion();
    const bool transparency = systemReducedTransparency();
    if ((motion == m_reducedMotion) && (transparency == m_reducedTransparency))
        return;

    m_reducedMotion = motion;
    m_reducedTransparency = transparency;
    emit changed();
}
