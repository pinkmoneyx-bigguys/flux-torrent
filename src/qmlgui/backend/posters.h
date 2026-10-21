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
#include <QDateTime>
#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QString>
#include <QTimer>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

class QJSEngine;
class QQmlEngine;

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
    // the key of a film of this title (the original one when there is one) and year
    static QString keyOf(const QString &title, const QString &original, int year);

    // a title to compare with another one: folded case, ё as е, words only ("Faster Than Light: the
    // Dream…" and "Faster than light. The dream…" are the same)
    static QString comparable(const QString &title);
};

// Film posters for search results, looked up by title and year in several public sources (no keys needed),
// one after another until one has the film: IMDb's title suggestions by the original title, then by the
// local one, Russian and English Wikipedia, Shikimori (anime). Each site gets a couple of requests at a time
// and a failed one is retried. What was found (or not) is kept on disk, so a film is looked up once; QML
// reads poster(key) again when `revision` changes. Requests go through the app's download manager.
class Posters : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(Posters)
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged FINAL)

public:
    // the one instance (QML's singleton is this one too), so the result filter can ask about posters
    static Posters *instance();
    static Posters *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    int revision() const;

    // FilmInfo::parse as {key, title, original, year, quality, series}
    Q_INVOKABLE QVariantMap film(const QString &name) const;
    // The poster URL found for `key`, or "" (not looked up yet, or none)
    Q_INVOKABLE QString poster(const QString &key) const;
    // The poster of `key` to show: a file kept on disk, fetched through the app's download manager the
    // first time ("" until it is there; the web address itself without a profile, in tests). Pictures
    // asked for straight from QML went missing now and then when many came from one server at once.
    Q_INVOKABLE QString image(const QString &key);
    // Looks the film up unless it was already (or is being)
    Q_INVOKABLE void request(const QString &key, const QString &title, const QString &original, int year, bool series = false);
    // Looks a film without a poster up again now, even one no source had a little while ago (its card was
    // opened: worth another try)
    Q_INVOKABLE void retry(const QString &key, const QString &title, const QString &original, int year, bool series = false);
    // A poster from elsewhere (the film's Wikipedia page) for a film that has none
    void offer(const QString &key, const QString &url);

    // `key` is another name of the film `target`: it has that film's poster (and isn't looked up itself)
    void alias(const QString &key, const QString &target);
    bool hasAlias(const QString &key) const;

    // Sets the poster of `key` (tests and demos)
    Q_INVOKABLE void setPoster(const QString &key, const QString &url);

    // The poster of the film called `title`, of `year` (0: any), in a source's answer, sized for a card;
    // "" when the answer has no film that surely is this one
    static QString pickImdb(const QByteArray &json, const QString &title, int year, bool series);
    static QString pickWikipedia(const QByteArray &json, const QString &title, int year, bool series);
    static QString pickShikimori(const QByteArray &json, const QString &title, int year);

signals:
    void revisionChanged();

private:
    explicit Posters(const QString &cachePath, QObject *parent = nullptr);
    ~Posters() override;

    enum Source
    {
        ImdbOriginal,
        ImdbLocal,
        WikipediaRu,
        WikipediaEn,
        Shikimori,
        SourceCount
    };

    struct Job
    {
        QString key;
        QString title;
        QString original;
        int year = 0;
        bool series = false;
        int source = ImdbOriginal;
        int attempt = 0;
        // a source answered (without the film): only then is "none anywhere" worth remembering
        bool answered = false;
    };

    // the query `job` makes at its source, or "" when that source can't look this film up
    static QString queryOf(const Job &job);
    static QString urlOf(const Job &job);
    void enqueueNext(Job job);
    void pump();
    void finished(const Job &job, bool ok, const QByteArray &data);
    void found(const QString &key, const QString &url);

    void load();
    void write();
    // the file a poster address is kept in
    QString fileOf(const QString &url) const;
    void fetchImage(const QString &url, int attempt = 0);
    // keeps the folder of pictures to the newest few hundred
    void pruneImages();

    QString m_cachePath;
    QHash<QString, QString> m_posters;
    QHash<QString, QString> m_aliases;
    QHash<QString, QDateTime> m_missed;
    QSet<QString> m_asked;
    QSet<QString> m_looking;  // keys being looked up now
    QString m_imageDir;       // the pictures, beside the cache file ("" without a profile)
    QSet<QString> m_fetching; // poster addresses being downloaded
    QSet<QString> m_failed;   // addresses that would not come this session
    QList<Job> m_queues[SourceCount];
    int m_running[SourceCount] = {};
    int m_revision = 0;
    QTimer m_writeTimer;
};
