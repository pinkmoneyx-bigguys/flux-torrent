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
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>

#include "base/search/searchhandler.h"

// What a source knows of a release beyond its name (JacRed has it; a Python plugin's result has none)
struct ReleaseMeta
{
    QString title;          // the local title, clean ("Киберпанк: Бегущие по краю")
    QString original;       // the original one
    int year = 0;
    QStringList voices;     // the voice-overs: studios ("LostFilm", "AniLibria") and kinds
    QList<int> seasons;
    QString video;          // "hdr", "dv", "sdr" or ""
};

struct JacRedResult
{
    SearchResult result;
    ReleaseMeta meta;
};

// One search on a JacRed server: the public aggregator of Russian trackers (rutracker, rutor, kinozal,
// nnmclub, megapeer…) that TV apps such as NUM and Lampa search through. It answers a plain HTTP query
// with JSON, so it needs no Python plugin. Results carry magnet links. The request goes through the
// app's download manager (its proxy settings apply).
class JacRedSearch : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(JacRedSearch)

public:
    static constexpr QStringView DEFAULT_URL = u"https://jac.red";

    explicit JacRedSearch(QObject *parent = nullptr);

    // `category`: "all", "movies", "tv", "anime" (others match nothing here)
    void start(const QString &baseUrl, const QString &pattern, const QString &category);
    void cancel();
    bool isActive() const;

    // The JSON answer as results, kept to `category`; the server's tracker names go in engineName
    static QList<JacRedResult> parse(const QByteArray &json, const QString &category, const QString &baseUrl);
    // Whether this source has anything for `category`
    static bool covers(const QString &category);

signals:
    void newResults(const QList<JacRedResult> &results);
    // `error` is empty on success
    void finished(const QString &error);

private:
    bool m_active = false;
    int m_generation = 0;
};
