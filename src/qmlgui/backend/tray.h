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

#include <QColor>
#include <QObject>
#include <QPoint>
#include <QWindow>
#include <QtQmlIntegration/qqmlintegration.h>

// What the icon in the notification area needs from outside QML: where its menu opens, how that menu's
// window looks on Windows 11, the one-time notice when the window first goes to the notification area,
// and the torrents that finish downloading (for the notification).
class Tray : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Tray)
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Tray(QObject *parent = nullptr);

    // Where a menu of this size opens at the mouse pointer: above it and to its right, flipped to stay
    // on the screen the pointer is on
    Q_INVOKABLE QPoint menuPosition(int width, int height) const;
    // Windows 11: the system's rounded corners and shadow, the border in `border`
    Q_INVOKABLE void decorate(QWindow *window, const QColor &border) const;
    // Brings the window to the front with the focus even while another program has it, so a click
    // anywhere else takes the focus away again (and the menu closes)
    Q_INVOKABLE void activate(QWindow *window) const;
    // True the first time the window goes to the notification area (and never again for this profile)
    Q_INVOKABLE bool takeHideNotice();
    // Flux is quitting (the tray menu, an update, Windows signing out): Qt first asks every window to
    // close, and one that hid itself in the notification area instead would call the quitting off
    Q_INVOKABLE bool isQuitting() const;

signals:
    void downloadFinished(const QString &name);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    bool m_quitting = false;
};
