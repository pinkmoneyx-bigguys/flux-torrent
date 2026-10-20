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
