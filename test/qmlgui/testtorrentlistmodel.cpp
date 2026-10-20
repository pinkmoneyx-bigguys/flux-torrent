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

#include <QObject>
#include <QTest>

#include "qmlgui/backend/torrentlistmodel.h"

using namespace Qt::Literals::StringLiterals;

class TestTorrentListModel final : public QObject
{
    Q_OBJECT
    Q_DISABLE_COPY_MOVE(TestTorrentListModel)

public:
    TestTorrentListModel() = default;

private slots:
    // A download with no data yet right after it was started is reaching its peers, not stalled
    void stalledRightAfterStartIsConnecting()
    {
        QCOMPARE(TorrentListModel::shownState(u"stalledDl"_s, 0), u"connecting"_s);
        QCOMPARE(TorrentListModel::shownState(u"stalledDl"_s, TorrentListModel::CONNECTING_MS - 1), u"connecting"_s);
    }

    void stalledLaterIsStalled()
    {
        QCOMPARE(TorrentListModel::shownState(u"stalledDl"_s, TorrentListModel::CONNECTING_MS), u"stalledDl"_s);
        // started before Flux knew (no time): as it is
        QCOMPARE(TorrentListModel::shownState(u"stalledDl"_s, -1), u"stalledDl"_s);
    }

    void otherStatesAreKept()
    {
        for (const QString &state : {u"downloading"_s, u"stalledUp"_s, u"queuedDl"_s, u"metadata"_s, u"stoppedDl"_s})
            QCOMPARE(TorrentListModel::shownState(state, 0), state);
    }
};

QTEST_APPLESS_MAIN(TestTorrentListModel)
#include "testtorrentlistmodel.moc"
