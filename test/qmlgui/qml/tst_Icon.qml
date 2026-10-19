import QtQuick
import QtTest
import Flux

TestCase {
    id: root
    name: "Icon"
    width: 200
    height: 100
    visible: true // grabImage captures the window, so the test case must be shown
    when: windowShown

    Icon { id: ic; path: Icons.download; size: 24; color: "black" }
    Icon { id: small; x: 40; path: Icons.search }

    function test_size() {
        compare(ic.width, 24)
        compare(ic.height, 24)
    }

    function test_defaults() {
        compare(small.size, 16)
        compare(small.strokeWidth, 1.5)
        compare(small.width, 16)
        verify(Qt.colorEqual(small.color, Theme.text))
    }

    function test_renders() {
        // the download arrow stem runs along x=12 from y=3 to y=15 on the 24 grid
        waitForRendering(ic)
        const img = grabImage(ic)
        verify(!Qt.colorEqual(img.pixel(12, 4), img.pixel(0, 0)))
    }

    function test_allIconsHavePaths() {
        const names = ["download", "upload", "search", "rss", "media", "settings", "play", "pause", "trash",
                       "up", "down", "more", "folder", "film", "disc", "data", "audio", "app", "close",
                       "minimize", "maximize", "turtle", "check", "plus", "chevronDown", "filter", "columns",
                       "magnet", "refresh", "logo"]
        for (const n of names) {
            verify(typeof Icons[n] === "string", n + " is a string")
            verify(Icons[n].length > 0, n + " is not empty")
        }
    }
}
