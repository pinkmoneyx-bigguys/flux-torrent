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

#include "tray.h"

#include <algorithm>

#include <QColor>
#include <QCoreApplication>
#include <QCursor>
#include <QEvent>
#include <QGuiApplication>
#include <QRect>
#include <QScreen>
#include <QWindow>

#ifdef Q_OS_WIN
#include <windows.h>
#include <dwmapi.h>
#endif

#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/global.h"
#include "base/settingsstorage.h"

namespace
{
    const QString HIDE_NOTICE_KEY = u"Flux/Tray/HideNoticeShown"_s;
}

Tray::Tray(QObject *parent)
    : QObject(parent)
{
    // QCoreApplication::quit() and the end of the Windows session arrive as QEvent::Quit, before the windows
    // are asked to close
    if (QCoreApplication *app = QCoreApplication::instance())
        app->installEventFilter(this);

    if (auto *session = BitTorrent::Session::instance())
    {
        connect(session, &BitTorrent::Session::torrentFinished, this, [this](const BitTorrent::Torrent *torrent)
        {
            emit downloadFinished(torrent->name());
        });
    }
}

QPoint Tray::menuPosition(const int width, const int height) const
{
    const QPoint cursor = QCursor::pos();
    const QScreen *screen = QGuiApplication::screenAt(cursor);
    if (!screen)
        screen = QGuiApplication::primaryScreen();
    const QRect area = screen ? screen->availableGeometry() : QRect(cursor - QPoint(width, height), QSize(2 * width, 2 * height));

    // above the pointer (the taskbar is usually at the bottom), below it when there is no room up there
    int x = cursor.x();
    int y = cursor.y() - height;
    if ((x + width) > (area.x() + area.width()))
        x = cursor.x() - width;
    if (y < area.y())
        y = cursor.y();
    x = std::clamp(x, area.x(), std::max(area.x(), area.x() + area.width() - width));
    y = std::clamp(y, area.y(), std::max(area.y(), area.y() + area.height() - height));
    return {x, y};
}

void Tray::decorate(QWindow *window, const QColor &border) const
{
#ifdef Q_OS_WIN
    if (!window)
        return;
    const auto hwnd = reinterpret_cast<HWND>(window->winId());
    // DWMWA_WINDOW_CORNER_PREFERENCE (33): DWMWCP_ROUNDSMALL, as Windows' own menus; DWMWA_BORDER_COLOR (34)
    const int corners = 3;
    ::DwmSetWindowAttribute(hwnd, 33, &corners, sizeof(corners));
    const COLORREF color = RGB(border.red(), border.green(), border.blue());
    ::DwmSetWindowAttribute(hwnd, 34, &color, sizeof(color));
#else
    Q_UNUSED(window);
    Q_UNUSED(border);
#endif
}

void Tray::activate(QWindow *window) const
{
    if (!window)
        return;
#ifdef Q_OS_WIN
    // Windows lets a program take the focus only from one that has it: join the input of the window in
    // front for the moment of the switch, as programs with menus in the notification area do
    const auto hwnd = reinterpret_cast<HWND>(window->winId());
    const DWORD self = ::GetCurrentThreadId();
    const DWORD front = ::GetWindowThreadProcessId(::GetForegroundWindow(), nullptr);
    const bool attached = (front != 0) && (front != self) && ::AttachThreadInput(self, front, TRUE);
    ::SetForegroundWindow(hwnd);
    ::BringWindowToTop(hwnd);
    ::SetFocus(hwnd);
    if (attached)
        ::AttachThreadInput(self, front, FALSE);
#endif
    window->requestActivate();
}

bool Tray::isQuitting() const
{
    return m_quitting;
}

bool Tray::eventFilter(QObject *watched, QEvent *event)
{
    if ((event->type() == QEvent::Quit) && (watched == QCoreApplication::instance()))
        m_quitting = true;
    return QObject::eventFilter(watched, event);
}

bool Tray::takeHideNotice()
{
    SettingsStorage *storage = SettingsStorage::instance();
    if (!storage || storage->loadValue<bool>(HIDE_NOTICE_KEY, false))
        return false;
    storage->storeValue(HIDE_NOTICE_KEY, true);
    return true;
}
