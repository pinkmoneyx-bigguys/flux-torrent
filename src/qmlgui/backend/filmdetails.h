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

#include <functional>

#include <QByteArray>
#include <QHash>
#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// What a film is about, for its card: the opening of its Wikipedia article in the interface language (else
// in English or Russian, whichever has it), with the link to the article it comes from (CC BY-SA asks for
// that). The article is found as the posters' Wikipedia look-up finds one: by the local title on the
// Russian Wikipedia or the original one on the English, then followed to the interface language. Kept for
// the session; QML reads details(key) again when `revision` changes.
class FilmDetails : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(FilmDetails)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)

public:
    explicit FilmDetails(QObject *parent = nullptr);

    int revision() const;

    // Looks the film up unless it was already
    Q_INVOKABLE void request(const QString &key, const QString &title, const QString &original, int year, bool series = false);
    // {state: "loading" | "ready" | "none", text, url, lang, image}; {} when never asked for
    Q_INVOKABLE QVariantMap details(const QString &key) const;

    // The title of the article about the film called `title` (of `year`, 0: any) in a search answer, or ""
    static QString pickArticle(const QByteArray &json, const QString &title, int year, bool series);
    // {text, url, image, langlink} of the one page of an extract answer; `langlink`: its title in the
    // language asked for, if it has one
    static QVariantMap readArticle(const QByteArray &json);
    // The opening of an article, cut at a sentence end to about `limit` characters
    static QString shorten(const QString &text, int limit = 700);

signals:
    void revisionChanged();

private:
    struct Job
    {
        QString key;
        QString title;
        QString original;
        int year = 0;
        bool series = false;
        int attempt = 0;     // which (wiki, title) of the search plan
        QString wiki;        // where the article was found
    };

    void search(Job job);
    void read(const Job &job, const QString &wiki, const QString &article, bool follow);
    void finish(const Job &job, const QVariantMap &result);
    void fetch(const QString &url, const std::function<void (bool, const QByteArray &)> &done);

    QHash<QString, QVariantMap> m_details;
    QString m_language;      // the interface language's Wikipedia
    int m_revision = 0;
};
