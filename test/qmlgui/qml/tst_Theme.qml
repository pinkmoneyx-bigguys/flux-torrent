import QtQuick
import QtTest
import Flux

TestCase {
    name: "Theme"

    function init() {
        Theme.style = "glass"
    }

    function cleanup() {
        Theme.style = "default"
        UiSettings.style = "default"
    }

    function test_defaultLookIsTheMainOne() {
        compare(UiSettings.style, "default")
    }

    function test_tokens() {
        compare(Theme.sp(3), 12)
        compare(Theme.radiusPanel, 24)
        compare(String(Theme.bg), "#08070d")
    }

    function test_defaultTokens() {
        Theme.style = "default"
        verify(!Theme.glass)
        compare(Theme.radiusPanel, 12)
        compare(Theme.radiusRow, 8)
        compare(Theme.radiusCtl, 8)
        verify(Qt.colorEqual(Theme.bg, "#171717"), "chrome is shadcn sidebar")
        verify(Qt.colorEqual(Theme.background, "#0A0A0A"), "content is shadcn background")
        verify(Qt.colorEqual(Theme.text, "#FAFAFA"))
        verify(Qt.colorEqual(Theme.textDim, "#A1A1A1"))
        fuzzyCompare(Theme.border.a, 0.10, 0.01)
        compare(Theme.fontText, "Geist")
        compare(Theme.fontMono, "Geist Mono")
    }

    function test_styleFollowsUiSettings() {
        Theme.style = Qt.binding(() => UiSettings.style)
        UiSettings.style = "glass"
        verify(Theme.glass)
        UiSettings.style = "something else"
        compare(UiSettings.style, "default", "unknown looks fall back to the default one")
        verify(!Theme.glass)
    }

    function test_accentAlpha() {
        const c = Theme.accentAlpha(0.5)
        fuzzyCompare(c.a, 0.5, 0.01)
        compare(Math.round(c.g * 255), 0xF0)
    }

    function test_fontsLoaded() {
        verify(Theme.fontText.length > 0)
        verify(Theme.fontMono.length > 0)
    }

    function test_fontFamilies() {
        compare(Theme.fontText, "Onest")
        compare(Theme.fontDisplay, "Unbounded")
        compare(Theme.fontMono, "JetBrains Mono")
    }

    function test_variableWeightApplied() {
        // the bundled fonts are variable: a heavier weight must really be a different face
        const regular = Qt.createQmlObject(
            'import QtQuick; import Flux; TextMetrics { font.family: Theme.fontText; font.pixelSize: 40; text: "Flux torrents" }',
            this)
        const bold = Qt.createQmlObject(
            'import QtQuick; import Flux; TextMetrics { font.family: Theme.fontText; font.pixelSize: 40; font.weight: Font.Bold; text: "Flux torrents" }',
            this)
        verify(bold.advanceWidth > regular.advanceWidth)
    }

    function test_radiiAndSpacing() {
        compare(Theme.radiusPill, 999)
        compare(Theme.radiusRow, 16)
        compare(Theme.radiusCtl, 12)
        compare(Theme.radiusSmall, 6)
        compare(Theme.gap, 12)
        compare(Theme.sp(0), 0)
    }

    function test_motion() {
        compare(Theme.durPress, 160)
        compare(Theme.durFast, 150)
        compare(Theme.durMed, 240)
        compare(Theme.durSlow, 340)
        compare(Theme.easing.type, Easing.BezierSpline)
        compare(Theme.easing.bezierCurve.length, 6)
        fuzzyCompare(Theme.easing.bezierCurve[0], 0.23, 0.0001)
    }

    function test_colors() {
        verify(Qt.colorEqual(Theme.text, "#EDEDF2"))
        verify(Qt.colorEqual(Theme.upload, "#B9A6FF"))
        verify(Qt.colorEqual(Theme.warn, "#FFB86B"))
        verify(Qt.colorEqual(Theme.error, "#FF7A8A"))
        fuzzyCompare(Theme.textDim.a, 0.64, 0.01)
        fuzzyCompare(Theme.textFaint.a, 0.56, 0.01)
        fuzzyCompare(Theme.glassOpacity, 0.46, 0.0001)
    }

    function test_accentWritable() {
        const original = String(Theme.accent) // a color property is a live reference, keep a copy
        Theme.accent = "#FF0000"
        compare(Theme.accentAlpha(1).r, 1)
        Theme.accent = original
        verify(Qt.colorEqual(Theme.accent, "#3EF0B0"))
    }

    function test_accessibilityFlagsWritable() {
        const motion = Theme.reducedMotion
        const transparency = Theme.reducedTransparency
        Theme.reducedMotion = !motion
        Theme.reducedTransparency = !transparency
        compare(Theme.reducedMotion, !motion)
        compare(Theme.reducedTransparency, !transparency)
        Theme.reducedMotion = motion
        Theme.reducedTransparency = transparency
    }
}
