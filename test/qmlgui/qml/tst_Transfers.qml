import QtQuick
import QtTest
import Flux

// The Transfers screen over rows fed through TorrentListModel.setRows (no session in tests):
// status counts and filters, search, sorting, selection, the details pane and the remove dialog.
TestCase {
    id: tc
    name: "Transfers"
    when: windowShown
    width: 1200
    height: 800
    visible: true

    readonly property var rows: [
        { id: "a", name: "ubuntu-25.10-desktop-amd64.iso", state: "downloading", size: 6000, progress: 0.5, dlSpeed: 900, category: "Linux" },
        { id: "b", name: "Big Buck Bunny 4K", state: "seeding", size: 9000, progress: 1, upSpeed: 300, category: "Movies" },
        { id: "c", name: "Sintel 1080p", state: "stoppedUp", size: 1000, progress: 1, category: "Movies" },
        { id: "d", name: "debian netinst", state: "stoppedDl", size: 500, progress: 0.2 },
        { id: "e", name: "planet.osm.pbf", state: "missing", size: 70000, progress: 0.3, error: "Files are missing" }
    ]

    TransfersPage {
        id: page
        anchors.fill: parent
    }

    function list() {
        return findChild(page, "transfersList")
    }

    function rowItem(i) {
        const lv = list()
        lv.positionViewAtIndex(i, ListView.Contain)
        return lv.itemAtIndex(i)
    }

    function init() {
        TorrentListModel.setRows(rows)
        TransfersState.status = "all"
        findChild(page, "transfersSearch").text = ""
        page.clearSelection()
        page.currentId = ""
        waitForRendering(page)
    }

    function test_counts() {
        const c = TorrentListModel.counts
        compare(c.all, 5)
        compare(c.downloading, 1)
        compare(c.seeding, 1)
        compare(c.completed, 2, "seeding and finished-then-stopped")
        compare(c.stopped, 2)
        compare(c.active, 2)
        compare(c.errored, 1)
    }

    function test_statusFilter() {
        compare(list().count, 5)
        TransfersState.status = "stopped"
        tryCompare(list(), "count", 2)
        TransfersState.status = "errored"
        tryCompare(list(), "count", 1)
        compare(list().model.idAt(0), "e")
    }

    function test_search() {
        findChild(page, "transfersSearch").text = "movies sintel"
        tryCompare(list(), "count", 1, 1000, "every word must match the name, category or tags")
        compare(list().model.idAt(0), "c")
    }

    function test_emptyStateForFilter() {
        findChild(page, "transfersSearch").text = "nothing like this"
        tryCompare(list(), "count", 0)
        verify(findChild(page, "transfersEmpty").visible)
    }

    function test_sortBySize() {
        page.sortBy("size")
        compare(list().model.sortKey, "size")
        verify(list().model.descending, "numbers sort largest first")
        compare(list().model.idAt(0), "e")
        page.sortBy("size")
        compare(list().model.idAt(0), "d", "second click: ascending")
        page.sortBy("size")
        compare(list().model.sortKey, "", "third click: back to the queue order")
        compare(list().model.idAt(0), "a")
    }

    function test_clickSelects() {
        mouseClick(rowItem(1), 200, 20)
        compare(page.selectedIds(), ["b"])
        compare(page.currentId, "b")
        verify(findChild(page, "transfersDetails").visible, "the details pane shows the clicked torrent")

        mouseClick(rowItem(3), 200, 20, Qt.LeftButton, Qt.ControlModifier)
        compare(page.selectedCount, 2, "ctrl-click adds")

        mouseClick(rowItem(4), 200, 20, Qt.LeftButton, Qt.ShiftModifier)
        compare(page.selectedIds().sort(), ["d", "e"], "shift-click selects the range from the focused row")
    }

    function test_keyboard() {
        mouseClick(rowItem(0), 200, 20)
        keyClick(Qt.Key_Down)
        compare(page.currentId, "b")
        compare(page.selectedIds(), ["b"])
        keyClick(Qt.Key_Down, Qt.ShiftModifier)
        compare(page.selectedIds().sort(), ["b", "c"])
        keyClick(Qt.Key_A, Qt.ControlModifier)
        compare(page.selectedCount, 5)
        keyClick(Qt.Key_Escape)
        compare(page.selectedCount, 0)
    }

    function test_deleteAsksFirst() {
        mouseClick(rowItem(2), 200, 20)
        keyClick(Qt.Key_Delete)
        const dialog = findChild(page, "removeDialog")
        tryCompare(dialog, "opened", true)
        compare(dialog.ids, ["c"])
        dialog.close()
        tryCompare(dialog, "visible", false)
        compare(TorrentListModel.count, 5, "nothing is removed without confirmation")
    }

    function test_selectionFollowsFilter() {
        mouseClick(rowItem(0), 200, 20)
        TransfersState.status = "seeding"
        tryCompare(list(), "count", 1)
        compare(page.selectedCount, 0, "a hidden row is no longer selected")
        compare(page.currentId, "", "and the details pane closes")
    }
}
