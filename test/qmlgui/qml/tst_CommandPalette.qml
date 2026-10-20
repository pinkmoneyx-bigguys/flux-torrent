import QtQuick
import QtTest
import Flux

// The Ctrl+K palette on its own: groups, filtering by words and keywords, matching torrents, the
// tracker-search entry, keyboard and mouse choice, and the empty state.
TestCase {
    id: tc
    name: "CommandPalette"
    when: windowShown
    width: 1000
    height: 700
    visible: true

    CommandPalette {
        id: palette
        actions: [
            { group: "Actions", id: "addTorrent", label: "Add torrent…", keywords: "open file" },
            { group: "Actions", id: "stopAll", label: "Stop all torrents", keywords: "pause" },
            { group: "Go to", id: "page", arg: 2, label: "RSS feeds" },
            { group: "Go to", id: "settings", arg: "speed", label: "Settings: speed", keywords: "limit schedule" }
        ]
        onTriggered: (id, arg) => { tc.lastId = id; tc.lastArg = arg }
    }

    property string lastId: ""
    property var lastArg

    function init() {
        lastId = ""
        lastArg = undefined
        TorrentListModel.setRows([
            { id: "u1", name: "ubuntu-25.10-desktop-amd64.iso", state: "downloading", progress: 0.5 },
            { id: "d1", name: "debian-13 netinst", state: "seeding", progress: 1 }
        ])
        palette.show()
        tryCompare(palette, "opened", true)
    }

    function cleanup() {
        palette.close()
        tryCompare(palette, "visible", false)
    }

    function labels() {
        return palette.rows.filter(r => !r.heading).map(r => r.label)
    }
    function headings() {
        return palette.rows.filter(r => r.heading).map(r => r.label)
    }

    function test_emptyQueryShowsGroups() {
        compare(headings(), ["Actions", "Go to"])
        compare(palette.selectableCount, 4)
        verify(findChild(palette.contentItem, "commandInput").activeFocus)
    }

    function test_filterByWordsAndKeywords() {
        keyClick(Qt.Key_P); keyClick(Qt.Key_A); keyClick(Qt.Key_U); keyClick(Qt.Key_S); keyClick(Qt.Key_E)
        compare(labels(), ["Stop all torrents", "Search trackers for “pause”"], "keywords match too")
    }

    function test_torrentsAppear() {
        findChild(palette.contentItem, "commandInput").text = "ubuntu"
        tryCompare(palette, "selectableCount", 2)
        compare(headings()[0], "Torrents")
        compare(palette.entryAt(0).arg, "u1")
    }

    function test_keyboardChoice() {
        findChild(palette.contentItem, "commandInput").text = "settings"
        keyClick(Qt.Key_Down)
        compare(palette.current, 1)
        keyClick(Qt.Key_Up)
        compare(palette.current, 0)
        keyClick(Qt.Key_Return)
        compare(lastId, "settings")
        compare(lastArg, "speed")
        tryCompare(palette, "visible", false, 1000, "choosing closes the palette")
        palette.show()
    }

    function test_trackerSearchEntry() {
        findChild(palette.contentItem, "commandInput").text = "big buck bunny"
        const last = palette.entryAt(palette.selectableCount - 1)
        compare(last.id, "searchTrackers")
        compare(last.arg, "big buck bunny")
    }

    function test_wrapAround() {
        keyClick(Qt.Key_Up)
        compare(palette.current, palette.selectableCount - 1, "up from the first entry goes to the last")
    }
}
