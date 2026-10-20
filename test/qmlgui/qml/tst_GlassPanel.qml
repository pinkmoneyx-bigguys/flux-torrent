import QtQuick
import QtTest
import Flux

TestCase {
    id: root
    name: "GlassPanel"
    // these are the Liquid Glass controls: check them in the glass look
    Component.onCompleted: Theme.style = "glass"
    width: 400
    height: 300
    visible: true // grabImage captures the window, so the test case must be shown
    when: windowShown

    GlassBackground { id: bg }
    GlassPanel {
        id: panel
        x: 100; y: 100; width: 200; height: 100
        radius: 24
        Item { id: inner; anchors.fill: parent }
    }
    Item {
        id: holder
        x: 20; y: 20; width: 120; height: 60
        GlassPanel { id: nested; x: 10; y: 10; width: 100; height: 40 }
    }

    readonly property color tintRgb: "#181622"

    function init() {
        // the glass is a shader: the offscreen platform has no GPU backend to run it
        if (Qt.platform.pluginName === "offscreen")
            skip("GlassPanel renders through a shader; run on a real display")
    }

    function initTestCase() {
        Theme.glassSource = bg
        tryVerify(() => bg.rebuildCount > 0, 2000, "the blurred backdrop is built once after start")
    }

    function cleanupTestCase() {
        Theme.glassSource = null
    }

    function cleanup() {
        const dirty = Theme.reducedTransparency || Theme.glassSource !== bg || panel.x !== 100
                      || !panel.highlight || !panel.visible || holder.x !== 20
        Theme.reducedTransparency = false
        Theme.glassSource = bg
        panel.x = 100
        panel.highlight = true
        panel.visible = true
        holder.x = 20
        if (dirty) // waitForRendering waits for the next frame; without a change it would only time out
            waitForRendering(panel)
    }

    // Device pixels per logical pixel of a grab of `item`
    function scale(img, item) {
        return img.width / item.width
    }

    function px(img, item, x, y) {
        const s = scale(img, item)
        return img.pixel(Math.floor(x * s), Math.floor(y * s))
    }

    // The window as it looks without the panel on top
    function backdrop() {
        panel.visible = false
        waitForRendering(bg)
        const img = grabImage(bg)
        panel.visible = true
        waitForRendering(panel)
        return img
    }

    function test_fillsParent() {
        compare(bg.width, root.width)
        compare(bg.height, root.height)
    }

    function test_contentGoesInside() {
        verify(inner.parent !== panel)
        compare(inner.parent.parent, panel)
        compare(inner.width, panel.width)
    }

    function test_region() {
        fuzzyCompare(panel.region.x, 100 / 400, 1e-6)
        fuzzyCompare(panel.region.y, 100 / 300, 1e-6)
        fuzzyCompare(panel.region.width, 200 / 400, 1e-6)
        fuzzyCompare(panel.region.height, 100 / 300, 1e-6)
    }

    function test_regionFollowsMove() {
        panel.x = 120
        fuzzyCompare(panel.region.x, 120 / 400, 1e-6)
    }

    function test_regionFollowsAncestorMove() {
        holder.x = 60
        waitForRendering(nested)
        fuzzyCompare(nested.region.x, 70 / 400, 1e-6)
        fuzzyCompare(nested.region.y, 30 / 300, 1e-6)
    }

    function test_cornerTransparent() {
        // grabImage grabs the window, so "transparent" means the backdrop shows through unchanged
        const under = backdrop()
        const img = grabImage(panel)
        verify(Qt.colorEqual(img.pixel(0, 0), px(under, bg, 100, 100)))
        verify(!Qt.colorEqual(px(img, panel, 100, 50), px(under, bg, 200, 150)))
    }

    function test_centerTinted() {
        const under = backdrop()
        const img = grabImage(panel)
        const c = px(img, panel, 100, 50)
        const b = px(under, bg, 200, 150)
        verify(c.a > 0.99)
        verify(!Qt.colorEqual(c, b))
        // tinted blur of a smooth backdrop: close to mix(backdrop, tint, glassOpacity)
        const t = Theme.glassOpacity
        fuzzyCompare(c.r, b.r * (1 - t) + tintRgb.r * t, 0.04)
        fuzzyCompare(c.g, b.g * (1 - t) + tintRgb.g * t, 0.04)
        fuzzyCompare(c.b, b.b * (1 - t) + tintRgb.b * t, 0.04)
    }

    function test_highlight() {
        let img = grabImage(panel)
        const lit = px(img, panel, 100, 0).r - px(img, panel, 100, 3).r
        verify(lit > 0.04, "top edge is lighter: " + lit)
        panel.highlight = false
        waitForRendering(panel)
        img = grabImage(panel)
        const unlit = px(img, panel, 100, 0).r - px(img, panel, 100, 3).r
        verify(Math.abs(unlit) < 0.02, "no top edge without highlight: " + unlit)
    }

    function test_backdropIsStatic() {
        // Recoloring the mint blob changes nothing on screen until the debounced rebuild regrabs the
        // blurred texture — both the visible backdrop and the glass sample it: nothing is blurred per frame.
        const old = String(Theme.accent) // a copy: Theme.accent itself is a live value-type reference
        const n = bg.rebuildCount
        const screenBefore = px(grabImage(bg), bg, 10, 10)
        const glassBefore = px(grabImage(panel), panel, 10, 10)
        Theme.accent = "#FF4FD8"
        compare(bg.rebuildCount, n, "no rebuild yet")
        verify(Qt.colorEqual(px(grabImage(bg), bg, 10, 10), screenBefore), "the backdrop waits for the rebuild")
        verify(Qt.colorEqual(px(grabImage(panel), panel, 10, 10), glassBefore), "the glass too")
        tryCompare(bg, "rebuildCount", n + 1)
        waitForRendering(panel)
        verify(!Qt.colorEqual(px(grabImage(bg), bg, 10, 10), screenBefore), "the backdrop follows after the rebuild")
        verify(!Qt.colorEqual(px(grabImage(panel), panel, 10, 10), glassBefore), "the glass follows after the rebuild")
        Theme.accent = old
        tryCompare(bg, "rebuildCount", n + 2)
    }

    function test_reducedTransparencySolid() {
        Theme.reducedTransparency = true
        waitForRendering(panel)
        const img = grabImage(panel)
        verify(Qt.colorEqual(px(img, panel, 100, 50), "#17151F"))
        verify(Qt.colorEqual(img.pixel(0, 0), px(backdrop(), bg, 100, 100)), "corners stay rounded")
    }

    function test_noGlassSourceFallsBackToSolid() {
        Theme.glassSource = null
        waitForRendering(panel)
        verify(Qt.colorEqual(px(grabImage(panel), panel, 100, 50), "#17151F"))
    }
}
