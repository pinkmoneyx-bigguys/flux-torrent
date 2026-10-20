import QtQuick
import QtTest
import Flux

// RollingText (odometer figures) and the speed graph's layout in small spaces.
TestCase {
    id: tc
    name: "Rolling"
    when: windowShown
    width: 600
    height: 400
    visible: true

    RollingText {
        id: rolling
        x: 10
        y: 10
        width: 160
        horizontalAlignment: Text.AlignRight
        font.family: Theme.fontMono
        font.pixelSize: 12
    }

    SpeedGraph {
        id: graph
        x: 10
        y: 60
        width: 500
        height: 300
    }

    function slots() {
        const row = rolling.children[0]
        const list = []
        for (let i = 0; i < row.children.length; ++i) {
            if (row.children[i].shown !== undefined)
                list.push(row.children[i])
        }
        return list
    }

    function init() {
        rolling.value = NaN
        rolling.text = ""
    }

    // One slot per character, counted from the right: the unit keeps its slot
    function test_slotsFromTheRight() {
        rolling.text = "9,5 MB/s"
        wait(50)
        const before = slots().map(s => s.shown)
        compare(before.length, 8)
        compare(before[0], "s", "slot 0 is the last character")
        rolling.text = "10,2 MB/s"
        const after = slots().map(s => s.shown)
        compare(after.length, 9, "a new leading place")
        compare(after[0], "s")
        compare(after[5], "2")
        compare(after[8], "1")
        compare(rolling.Accessible.name, "10,2 MB/s")
    }

    // A changed character rolls in, in the direction the value moved
    function test_rollsWithTheValue() {
        rolling.value = 10
        rolling.text = "10"
        wait(400)
        rolling.value = 12
        rolling.text = "12"
        const ones = slots()[0]
        compare(ones.shown, "2")
        compare(ones.leaving, "0")
        compare(ones.dir, 1, "up when the value grows")
        verify(ones.t < 1, "it is rolling")
        tryCompare(ones, "t", 1, 1000)
        rolling.value = 11
        rolling.text = "11"
        compare(slots()[0].dir, -1, "down when it falls")
    }

    // 24 → 29: only the ones roll; the tens stay as they are
    function test_onlyTheChangedDigitRolls() {
        rolling.value = 24
        rolling.text = "24"
        wait(450)
        rolling.value = 29
        rolling.text = "29"
        const s = slots()
        verify(s[0].t < 1, "the 4 → 9 place rolls")
        compare(s[1].t, 1, "the 2 does not move")
        tryCompare(s[0], "t", 1, 1000)
    }

    // A figure that gains a digit keeps its places (and their state): only the new one is added
    function test_placesSurviveGrowing() {
        rolling.text = "9,8"
        wait(450)
        const before = slots()
        rolling.text = "10,2"
        const after = slots()
        compare(after.length, 4)
        verify(after[0] === before[0] && after[1] === before[1] && after[2] === before[2], "the same slots")
        compare(after[1].t, 1, "the comma stays put")
        rolling.text = "9,8"
        compare(slots().length, 3, "and drops it again")
    }

    // A new leading place just stands there; it does not roll in
    function test_newPlaceDoesNotRoll() {
        rolling.text = "9"
        wait(450)
        rolling.text = "10"
        const s = slots()
        verify(s[0].t < 1, "9 → 0 rolls")
        compare(s[1].t, 1, "the new 1 does not")
        compare(s[1].shown, "1")
    }

    // Another figure (a reused list row): shown at once, nothing rolls
    function test_identityChangeSnaps() {
        rolling.identity = "a"
        rolling.text = "24"
        wait(450)
        rolling.identity = "b"
        rolling.text = "57"
        for (const s of slots())
            compare(s.t, 1, "no roll for a different figure")
        compare(slots().map(s => s.shown).join(""), "75")
        wait(50)
        rolling.text = "58"
        verify(slots()[0].t < 1, "its own changes roll again")
    }

    // The graph's legend keeps its figures across samples (it used to rebuild them every second)
    function test_legendFiguresPersist() {
        graph.height = 300
        const figure = findChild(graph, "legendDown").figure
        TorrentListModel.sampleHistory()
        TorrentListModel.sampleHistory()
        compare(findChild(graph, "legendDown").figure, figure, "the same figure item")
    }

    // The graph shows what fits: legend, time line and scale labels drop out as it shrinks
    function test_graphFitsSmallSpaces() {
        graph.height = 300
        verify(graph.showLegend && graph.showTime)
        compare(graph.scaleLabels, 3)

        graph.height = 90
        waitForRendering(graph)
        verify(!graph.showLegend, "no legend")
        verify(graph.showTime)
        compare(graph.scaleLabels, 1, "only the top of the scale")

        graph.height = 50
        waitForRendering(graph)
        verify(!graph.showTime, "no time line")
        compare(graph.scaleLabels, 1)

        graph.height = 30
        waitForRendering(graph)
        compare(graph.scaleLabels, 0, "no labels at all")
        graph.height = 300
    }
}
