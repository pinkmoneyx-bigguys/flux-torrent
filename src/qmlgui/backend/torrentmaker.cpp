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

#include "torrentmaker.h"

#include <QRegularExpression>
#include <QThreadPool>
#include <QUrl>

#include "base/bittorrent/addtorrentparams.h"
#include "base/bittorrent/session.h"
#include "base/bittorrent/torrent.h"
#include "base/bittorrent/torrentcreator.h"
#include "base/bittorrent/torrentdescriptor.h"
#include "base/global.h"
#include "base/utils/fs.h"

TorrentMaker::TorrentMaker(QObject *parent)
    : QObject(parent)
{
}

TorrentMaker::~TorrentMaker()
{
    cancel();
}

bool TorrentMaker::busy() const
{
    return !m_creator.isNull();
}

int TorrentMaker::progress() const
{
    return m_progress;
}

QString TorrentMaker::toLocalPath(const QString &urlOrPath) const
{
    const QString text = urlOrPath.trimmed();
    if (text.startsWith(u"file:", Qt::CaseInsensitive))
        return QUrl(text).toLocalFile();
    return text;
}

QString TorrentMaker::defaultOutput(const QString &source) const
{
    const Path sourcePath {toLocalPath(source)};
    if (sourcePath.isEmpty())
        return {};
    return (sourcePath.parentPath() / Path(sourcePath.filename() + u".torrent")).toString();
}

QString TorrentMaker::create(const QVariantMap &params)
{
    if (busy())
        return tr("A torrent is being created already.");

    const Path sourcePath {toLocalPath(params.value(u"source"_s).toString())};
    if (sourcePath.isEmpty())
        return tr("Choose a file or folder to share.");
    if (!sourcePath.exists() || !Utils::Fs::isReadable(sourcePath))
        return tr("The file or folder cannot be read.");

    QString output = toLocalPath(params.value(u"output"_s).toString());
    if (output.isEmpty())
        output = defaultOutput(sourcePath.toString());
    Path torrentPath {output};
    if (!torrentPath.hasExtension(u".torrent"_s))
        torrentPath += u".torrent"_s;

    // one tracker per line; blank lines separate tiers (runs of them count as one)
    const QStringList trackers = params.value(u"trackers"_s).toString().trimmed()
        .replace(QRegularExpression(u"\n\n[\n]+"_s), u"\n\n"_s).split(u'\n');
    const QString format = params.value(u"format"_s).toString();

    const BitTorrent::TorrentCreatorParams creatorParams
    {
        .isPrivate = params.value(u"isPrivate"_s).toBool(),
#ifdef QBT_USES_LIBTORRENT2
        .torrentFormat = (format == u"v1") ? BitTorrent::TorrentFormat::V1
            : (format == u"v2") ? BitTorrent::TorrentFormat::V2 : BitTorrent::TorrentFormat::Hybrid,
#endif
        .pieceSize = params.value(u"pieceSize"_s).toInt(),
        .sourcePath = sourcePath,
        .torrentFilePath = torrentPath,
        .comment = params.value(u"comment"_s).toString(),
        .source = params.value(u"sourceTag"_s).toString(),
        .trackers = trackers,
        .urlSeeds = params.value(u"webSeeds"_s).toString().split(u'\n', Qt::SkipEmptyParts)
    };
    m_startSeeding = params.value(u"startSeeding"_s, true).toBool();

    auto *creator = new BitTorrent::TorrentCreator(creatorParams);
    m_creator = creator;
    connect(creator, &BitTorrent::TorrentCreator::progressUpdated, this, &TorrentMaker::setProgress);
    connect(creator, &BitTorrent::TorrentCreator::creationFailure, this, [this](const QString &message)
    {
        m_creator.clear();
        setProgress(0);
        emit busyChanged();
        emit failed(message);
    });
    connect(creator, &BitTorrent::TorrentCreator::creationSuccess, this, [this](const BitTorrent::TorrentCreatorResult &result)
    {
        m_creator.clear();
        setProgress(100);
        emit busyChanged();

        bool seeding = false;
        auto *session = BitTorrent::Session::instance();
        if (m_startSeeding && session)
        {
            if (const auto loaded = BitTorrent::TorrentDescriptor::loadFromFile(result.torrentFilePath))
            {
                // every value set here: the global defaults (stopped, auto TMM, ratio limits) must not apply
                BitTorrent::AddTorrentParams addParams;
                addParams.addStopped = false;
                addParams.contentLayout = BitTorrent::TorrentContentLayout::Original;
                addParams.savePath = result.savePath;
                addParams.skipChecking = true;
                addParams.stopCondition = BitTorrent::Torrent::StopCondition::None;
                addParams.useAutoTMM = false;
                addParams.useDownloadPath = false;
                seeding = session->addTorrent(loaded.value(), addParams);
            }
        }
        emit created(result.torrentFilePath.toString(), seeding);
    });

    setProgress(0);
    emit busyChanged();
    QThreadPool::globalInstance()->start(creator);
    return {};
}

void TorrentMaker::cancel()
{
    if (m_creator)
        m_creator->requestInterruption();
}

void TorrentMaker::setProgress(const int progress)
{
    if (progress == m_progress)
        return;
    m_progress = progress;
    emit progressChanged();
}
