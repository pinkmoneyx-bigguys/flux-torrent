pragma Singleton
import QtQuick

// Design tokens of the Flux "Liquid Glass" shell. Everything visual reads its colors, radii, spacing,
// fonts and motion from here so the look can be changed in one place.
QtObject {
    id: theme

    // --- Colors ---------------------------------------------------------------------------------
    property color accent: "#3EF0B0"
    readonly property color bg: "#08070D"
    readonly property color text: "#EDEDF2"
    readonly property color textDim: Qt.rgba(1, 1, 1, 0.64)
    readonly property color textFaint: Qt.rgba(1, 1, 1, 0.56)
    readonly property color upload: "#B9A6FF"
    readonly property color warn: "#FFB86B"
    readonly property color error: "#FF7A8A"

    // The current accent with its alpha channel replaced by `a` (0..1)
    function accentAlpha(a) {
        return Qt.rgba(accent.r, accent.g, accent.b, a)
    }

    // --- Radii ----------------------------------------------------------------------------------
    readonly property int radiusPill: 999
    readonly property int radiusPanel: 24
    readonly property int radiusRow: 16
    readonly property int radiusCtl: 12
    readonly property int radiusSmall: 6

    // --- Spacing: 4px grid ----------------------------------------------------------------------
    function sp(n) {
        return 4 * n
    }
    readonly property int gap: 12

    // --- Fonts ----------------------------------------------------------------------------------
    // The bundled fonts are variable: pick weights through font.weight (Regular/Medium/DemiBold/Bold)
    readonly property FontLoader fontTextLoader: FontLoader { source: "fonts/Onest-Variable.ttf" }
    readonly property FontLoader fontDisplayLoader: FontLoader { source: "fonts/Unbounded-Variable.ttf" }
    readonly property FontLoader fontMonoLoader: FontLoader { source: "fonts/JetBrainsMono-Variable.ttf" }
    readonly property string fontText: fontTextLoader.name
    readonly property string fontDisplay: fontDisplayLoader.name
    readonly property string fontMono: fontMonoLoader.name

    // --- Motion ---------------------------------------------------------------------------------
    // Use as: easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve
    readonly property var easing: ({ type: Easing.BezierSpline, bezierCurve: [0.23, 1, 0.32, 1, 1, 1] })
    readonly property int durPress: 160
    readonly property int durFast: 150
    readonly property int durMed: 240
    readonly property int durSlow: 340

    // --- Accessibility: Windows settings, plain properties so tests can override them -----------
    property bool reducedMotion: SystemPrefs.reducedMotion
    property bool reducedTransparency: SystemPrefs.reducedTransparency

    // --- Glass ----------------------------------------------------------------------------------
    readonly property real glassOpacity: 0.46
    // The item that is blurred behind glass panels; assigned by Main.qml
    property Item glassSource: null
}
