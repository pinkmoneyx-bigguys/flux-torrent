pragma Singleton
import QtQuick
import Flux

// Design tokens of the Flux shell. Everything visual reads its colors, radii, spacing, fonts and motion
// from here. Two looks share the same token names:
//   "default" — the main look, after shadcn/ui (neutral dark palette, 1 px borders, restrained radii);
//   "glass"   — Liquid Glass (frosted panels over a coloured backdrop), chosen in Settings → Interface.
QtObject {
    id: theme

    // --- Look -----------------------------------------------------------------------------------
    // Plain property bound to the saved choice, so tests can switch it without touching the profile
    property string style: UiSettings.style
    readonly property bool glass: style === "glass"

    // --- Colors ---------------------------------------------------------------------------------
    // Liquid Glass brand accent (mint); the glass backdrop follows it
    property color accent: "#3EF0B0"

    // Window chrome behind everything: the title strip and the sidebar
    readonly property color bg: glass ? "#08070D" : "#171717"
    // The content area (shadcn "background"), the inset card the pages live on
    readonly property color background: glass ? "transparent" : "#0A0A0A"
    readonly property color card: glass ? Qt.rgba(1, 1, 1, 0.06) : "#171717"
    readonly property color popover: glass ? "#1B1925" : "#171717"
    readonly property color muted: glass ? Qt.rgba(1, 1, 1, 0.08) : "#262626"
    // Hover and selected fills (shadcn "accent" / "sidebar-accent")
    readonly property color hover: glass ? Qt.rgba(1, 1, 1, 0.08) : "#262626"
    readonly property color selected: glass ? Qt.rgba(1, 1, 1, 0.12) : "#262626"
    readonly property color border: Qt.rgba(1, 1, 1, glass ? 0.12 : 0.10)
    readonly property color input: Qt.rgba(1, 1, 1, glass ? 0.14 : 0.15)
    readonly property color inputFill: Qt.rgba(1, 1, 1, glass ? 0 : 0.045) // input/30 over #0A0A0A
    readonly property color ring: glass ? accent : "#737373"

    readonly property color text: glass ? "#EDEDF2" : "#FAFAFA"
    readonly property color textDim: glass ? Qt.rgba(1, 1, 1, 0.64) : "#A1A1A1"
    readonly property color textFaint: glass ? Qt.rgba(1, 1, 1, 0.56) : "#737373"

    readonly property color primary: glass ? accent : "#E5E5E5"
    readonly property color primaryText: glass ? "#08070D" : "#171717"

    // Status colors (same meaning in both looks)
    readonly property color download: glass ? accent : "#60A5FA"   // blue-400
    readonly property color upload: glass ? "#B9A6FF" : "#4ADE80"  // green-400: seeding
    readonly property color warn: glass ? "#FFB86B" : "#FBBF24"
    readonly property color error: glass ? "#FF7A8A" : "#FF6467"

    // The current accent with its alpha channel replaced by `a` (0..1)
    function accentAlpha(a) {
        return Qt.rgba(accent.r, accent.g, accent.b, a)
    }
    // Any color with its alpha replaced by `a`
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // --- Radii ----------------------------------------------------------------------------------
    readonly property int radiusPill: 999
    readonly property int radiusPanel: glass ? 24 : 12  // panels and the content inset
    readonly property int radiusRow: glass ? 16 : 8     // list rows and menu items
    readonly property int radiusCtl: glass ? 12 : 8     // buttons and inputs (shadcn rounded-md)
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
    readonly property FontLoader fontSansLoader: FontLoader { source: "fonts/Geist-Variable.ttf" }
    readonly property FontLoader fontSansMonoLoader: FontLoader { source: "fonts/GeistMono-Variable.ttf" }
    readonly property string fontText: glass ? fontTextLoader.name : fontSansLoader.name
    readonly property string fontDisplay: glass ? fontDisplayLoader.name : fontSansLoader.name
    readonly property string fontMono: glass ? fontMonoLoader.name : fontSansMonoLoader.name

    // Type scale (shadcn text-xs / text-sm / text-base, a notch denser for a desktop window)
    readonly property int textXs: 12
    readonly property int textSm: 13
    readonly property int textBase: 14
    readonly property int textTitle: glass ? 22 : 15

    // --- Motion ---------------------------------------------------------------------------------
    // Use as: easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve
    readonly property var easing: ({ type: Easing.BezierSpline, bezierCurve: [0.23, 1, 0.32, 1, 1, 1] })
    readonly property int durPress: 160
    readonly property int durFast: 150
    readonly property int durMed: 240
    readonly property int durSlow: 340
    // Value changes of bars and gauges: long enough to read as movement, not as a jump
    readonly property int durValue: 600

    // One shared clock for every progress shimmer, so the sweeps on a list move together. It runs only
    // while some bar shimmers (UiProgress counts itself in and out), not for the life of the app.
    property int shimmerUsers: 0
    property real shimmerPhase: 0
    readonly property SequentialAnimation _shimmerClock: SequentialAnimation {
        running: theme.shimmerUsers > 0
        loops: Animation.Infinite
        NumberAnimation { target: theme; property: "shimmerPhase"; from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 400 }
    }

    // --- Accessibility: Windows settings, plain properties so tests can override them -----------
    property bool reducedMotion: SystemPrefs.reducedMotion
    property bool reducedTransparency: SystemPrefs.reducedTransparency

    // --- Glass ----------------------------------------------------------------------------------
    readonly property real glassOpacity: 0.46
    // The item that is blurred behind glass panels; assigned by Main.qml
    property Item glassSource: null
}
