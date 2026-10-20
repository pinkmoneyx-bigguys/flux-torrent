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
        { id: "a", name: "ubuntu-25.10-desktop-amd64.iso", state: "downloading", size: 6000, progress: 0.5, dlSpeed: 900, category: "Linux",
          seeds: 12, seedsTotal: 340, peers: 3, peersTotal: 25 },
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

    function rowById(id) {
        for (let i = 0; i < list().count; ++i) {
            const r = rowItem(i)
            if (r && r.torrentId === id)
                return r
        }
        return null
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

    // Under the name: the state in its colour (an error shows its message); the kind of content is a
    // tile before the name; a running download's bar shimmers
    function test_statusLineKindAndShimmer() {
        const down = rowById("a")
        compare(findChild(down, "rowStatus").text, TorrentStatus.label("downloading"))
        compare(findChild(down, "kindTile").kind, "disc", "an .iso is a disc image")
        verify(findChild(down, "rowProgress").active, "a running download shimmers")
        verify(Theme.shimmerUsers > 0, "the shared shimmer clock runs")

        verify(!findChild(rowById("d"), "rowProgress").active, "a stopped one does not")

        const broken = rowById("e")
        compare(findChild(broken, "rowStatus").text, "Files are missing", "an error shows its message")
        compare(findChild(broken, "kindTile").kind, "archive")
        compare(page.kindOf("Sintel (2010) 2160p HEVC"), "video")
        compare(page.kindOf("NASA Apollo 11 FLAC"), "audio")
    }

    // Speed: download over upload; seeds / peers connected, the swarm in the tooltip
    function test_speedAndSwarm() {
        page.widths = Object.assign({}, page.defaultWidths)
        waitForRendering(page)
        const row = rowById("a")
        verify(findChild(page, "header_swarm").visible)
        compare(findChild(row, "cell_swarm").text, "12 / 3")
        const speed = findChild(row, "cell_speed")
        verify(speed.children[0].text.indexOf("↓") === 0 && speed.children[0].text.indexOf("—") < 0, speed.children[0].text)
        compare(speed.children[1].text, "↑ —", "no upload yet")
    }

    // Every row puts its columns at the same x, whatever its name
    function test_columnsLineUp() {
        const xs = []
        for (let i = 0; i < 5; ++i) {
            const r = rowItem(i)
            const cell = findChild(r, "cell_speed")
            xs.push(cell.mapToItem(page, 0, 0).x)
        }
        for (const x of xs)
            compare(x, xs[0], "the speed column lines up: " + xs)
    }

    // Dragging a header edge resizes the column; Name gives way; double-click restores the default
    function test_resizeColumns() {
        page.widths = Object.assign({}, page.defaultWidths)
        waitForRendering(page)
        const grip = findChild(page, "resizer_size")
        verify(grip && grip.visible)
        const before = page.cw("size")
        mouseDrag(grip, grip.width / 2, grip.height / 2, 40, 0)
        tryVerify(() => Math.abs(page.cw("size") - (before + 40)) <= 2, 1000, "size grew by the drag: " + page.cw("size"))
        compare(UiSettings.columnWidths("transfers").size, page.cw("size"), "the width is remembered")

        page.resizeColumn("size", 5)
        compare(page.cw("size"), page.minWidths.size, "never narrower than its minimum")
        page.resizeColumn("size", 100000)
        verify(page.nameWidth() >= page.nameMin - 1, "Name keeps its minimum")

        mouseDoubleClickSequence(grip, grip.width / 2, grip.height / 2)
        compare(page.cw("size"), page.defaultWidths.size, "double-click restores the default")

        // Name's edge moves the boundary with Size: dragging right narrows Size
        const nameGrip = findChild(page, "resizer_name")
        const sizeBefore = page.cw("size")
        mouseDrag(nameGrip, nameGrip.width / 2, nameGrip.height / 2, 20, 0)
        tryVerify(() => page.cw("size") < sizeBefore, 1000, "Size gave way: " + page.cw("size"))
        page.widths = Object.assign({}, page.defaultWidths)
    }

    // Every torrent's rates are sampled into a history; the details pane draws it on its Speed tab
    function test_speedHistoryAndGraph() {
        TorrentListModel.sampleHistory()
        TorrentListModel.sampleHistory()
        const h = TorrentListModel.speedHistory("a")
        verify(h.down.length >= 2, "two samples or more: " + h.down.length)
        verify(h.down[h.down.length - 1] > 0, "a downloading torrent has a download rate")
        verify(TorrentListModel.speedHistory("").down.length >= 2, "and so does the total")
        compare(TorrentListModel.speedHistory("nope").down.length, 0)

        page.currentId = "a"
        const pane = findChild(page, "transfersDetails")
        tryVerify(() => pane.visible)
        pane.tab = "speed"
        const graph = findChild(pane, "detailsSpeedGraph")
        tryVerify(() => graph.visible, 1000)
        compare(graph.torrentId, "a")
        verify(graph.down.length >= 2)
        verify(graph.peak >= graph.lastDown, "the scale covers the rates")
        pane.tab = "general"
        page.currentId = ""
    }

    // The details pane is as tall as its top edge is dragged; double-click goes back to automatic
    function test_detailsHeightDrag() {
        page.currentId = "a"
        const pane = findChild(page, "transfersDetails")
        tryVerify(() => pane.visible)
        tryCompare(pane, "height", pane.openHeight, 2000)
        const before = pane.height
        const grip = findChild(pane, "detailsHeightGrip")
        // press and move in page coordinates: the grip rises with the edge, the pointer does not
        const at = grip.mapToItem(page, grip.width / 2, grip.height / 2)
        mousePress(page, at.x, at.y)
        for (let dy = 10; dy <= 60; dy += 10)
            mouseMove(page, at.x, at.y - dy)
        mouseRelease(page, at.x, at.y - 60)
        tryVerify(() => Math.abs(pane.height - (before + 60)) <= 3, 2000, "60 px taller: " + pane.height)
        compare(UiSettings.layoutValue("detailsHeight", 0), pane.chosenHeight, "remembered")
        mouseDoubleClickSequence(grip, grip.width / 2, grip.height / 2)
        compare(pane.chosenHeight, 0)
        page.currentId = ""
    }

    // A long error under the name elides inside the name column, never over the size
    function test_longStatusElides() {
        const longError = "Files are missing: E:/Maps/planet-latest.osm.pbf and a lot more of a very long path that goes on and on"
        TorrentListModel.setRows([{ id: "x", name: "planet.osm.pbf", state: "missing", size: 70000, progress: 0.3, error: longError }])
        waitForRendering(page)
        const row = rowById("x")
        const status = findChild(row, "rowStatus")
        compare(status.text, longError)
        verify(status.truncated, "it is cut short")
        const statusRight = status.mapToItem(page, status.width, 0).x
        const nameRight = findChild(row, "kindTile").parent.mapToItem(page, findChild(row, "kindTile").parent.width, 0).x
        verify(statusRight <= nameRight + 0.5, "inside the name column: " + statusRight + " <= " + nameRight)
    }

    // The graph's shift follows the clock from the very frame new samples land
    function test_graphShiftInStepWithSamples() {
        page.currentId = "a"
        const pane = findChild(page, "transfersDetails")
        tryVerify(() => pane.visible)
        pane.tab = "speed"
        const graph = findChild(pane, "detailsSpeedGraph")
        tryVerify(() => graph.visible, 1000)
        TorrentListModel.sampleHistory()
        verify(graph.phase < 0.2, "a fresh sample starts the shift over at once: " + graph.phase)
        pane.tab = "general"
        page.currentId = ""
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
