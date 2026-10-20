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

#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

// What the About section shows: Flux's version and build, the libraries it runs on, where its profile
// lives, and the project's links (the GitHub repository is set at build time: FLUX_GITHUB_REPO).
class AppInfo : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(AppInfo)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString version READ version CONSTANT FINAL)
    Q_PROPERTY(QString commit READ commit CONSTANT FINAL)
    Q_PROPERTY(QString buildDate READ buildDate CONSTANT FINAL)
    // the qBittorrent release Flux is built on
    Q_PROPERTY(QString baseVersion READ baseVersion CONSTANT FINAL)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT FINAL)
    Q_PROPERTY(QString libtorrentVersion READ libtorrentVersion CONSTANT FINAL)
    Q_PROPERTY(QString boostVersion READ boostVersion CONSTANT FINAL)
    Q_PROPERTY(QString opensslVersion READ opensslVersion CONSTANT FINAL)
    Q_PROPERTY(QString zlibVersion READ zlibVersion CONSTANT FINAL)
    // "owner/name" on GitHub, or "" when the build has none
    Q_PROPERTY(QString repository READ repository CONSTANT FINAL)
    Q_PROPERTY(QString repositoryUrl READ repositoryUrl CONSTANT FINAL)
    Q_PROPERTY(QString releasesUrl READ releasesUrl CONSTANT FINAL)
    Q_PROPERTY(QString issuesUrl READ issuesUrl CONSTANT FINAL)
    Q_PROPERTY(QString profilePath READ profilePath CONSTANT FINAL)

public:
    explicit AppInfo(QObject *parent = nullptr);

    static QString name();
    static QString version();
    QString commit() const;
    QString buildDate() const;
    QString baseVersion() const;
    QString qtVersion() const;
    QString libtorrentVersion() const;
    QString boostVersion() const;
    QString opensslVersion() const;
    QString zlibVersion() const;
    static QString repository();
    QString repositoryUrl() const;
    QString releasesUrl() const;
    QString issuesUrl() const;
    QString profilePath() const;

    Q_INVOKABLE void openUrl(const QString &url) const;
    Q_INVOKABLE void openProfileFolder() const;
    // Version and library lines on the clipboard, for a bug report
    Q_INVOKABLE void copyDiagnostics() const;
};
