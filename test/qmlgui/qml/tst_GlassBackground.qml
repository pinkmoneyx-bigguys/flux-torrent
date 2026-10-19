import QtQuick
import QtTest
import Flux

TestCase {
    id: root
    name: "GlassBackground"
    width: 400
    height: 300
    visible: true // grabImage captures the window, so the test case must be shown
    when: windowShown

    // Detached from the parent so the test can drive its size directly
    GlassBackground { id: bg; anchors.fill: undefined; width: 400; height: 300 }

    function init() {
        bg.width = 400
        bg.height = 300
        wait(200) // let any pending rebuild from a previous test fire
    }

    function test_blurredSourceIsStatic() {
        verify(bg.blurredSource !== null)
        verify(bg.blurredSource instanceof ShaderEffectSource)
        compare(bg.blurredSource.live, false)
    }

    function test_debouncedRebuild() {
        const n = bg.rebuildCount
        for (let i = 0; i < 20; ++i) {
            bg.width += 3
            wait(5)
        }
        wait(200)
        compare(bg.rebuildCount, n + 1)
    }

    function test_accentRebuilds() {
        const old = String(Theme.accent) // a copy: Theme.accent itself is a live value-type reference
        const n = bg.rebuildCount
        Theme.accent = "#FF4FD8"
        wait(200)
        compare(bg.rebuildCount, n + 1)
        Theme.accent = old
        wait(200)
        compare(bg.rebuildCount, n + 2)
    }

    function test_rendersBlobs() {
        waitForRendering(bg)
        const img = grabImage(bg)
        // the violet blob covers the top-left area, the blue one the bottom: neither is the plain base color
        verify(!Qt.colorEqual(img.pixel(img.width / 4, img.height / 4), Theme.bg))
        verify(!Qt.colorEqual(img.pixel(img.width / 2, img.height - 2), Theme.bg))
        verify(!Qt.colorEqual(img.pixel(img.width / 4, img.height / 4), img.pixel(img.width - 2, img.height - 2)))
    }
}
