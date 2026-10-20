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

#include <QByteArray>
#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// What film a release is: parsed from its name ("Интерстеллар / Interstellar (Кристофер Нолан) [2014, …]
// BDRip 1080p", or a scene name like "Interstellar.2014.1080p.BluRay.x264"). `key` groups the releases of
// one film: the original title (else the first one) folded to lower case, and the year.
struct FilmInfo
{
    QString key;
    QString title;      // the first (local) title
    QString original;   // a Latin-script title when the name has one
    int year = 0;
    QString quality;    // "2160p", "1080p", "720p"…
    bool series = false;

    static FilmInfo parse(const QString &name);
    QVariantMap toMap() const;
};

// Film posters for search results, looked up by title and year in IMDb's public title suggestions (no key
// needed). Requests queue (a few at a time) and each film is asked about once a session; QML reads
// poster(key) again when `revision` changes. Requests go through the app's download manager.
class Posters : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Posters)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)

public:
    explicit Posters(QObject *parent = nullptr);

    int revision() const;

    // FilmInfo::parse as {key, title, original, year, quality, series}
    Q_INVOKABLE QVariantMap film(const QString &name) const;
    // The poster URL found for `key`, or "" (not looked up yet, or none)
    Q_INVOKABLE QString poster(const QString &key) const;
    // Looks the film up unless it was already (or is being)
    Q_INVOKABLE void request(const QString &key, const QString &title, const QString &original, int year, bool series = false);

    // The best poster in an IMDb suggestion answer for a film of `year` (0: any), sized for a card
    static QString pickPoster(const QByteArray &json, int year, bool series);

signals:
    void revisionChanged();

private:
    struct Job
    {
        QString key;
        QString query;
        int year = 0;
        bool series = false;
    };
    void pump();

    QHash<QString, QString> m_posters;
    QSet<QString> m_asked;
    QList<Job> m_queue;
    int m_running = 0;
    int m_revision = 0;
};
