import QtQuick
import Flux

// A pane of frosted glass: shows its own region of the pre-blurred backdrop (Theme.glassSource),
// tinted, with SDF-rounded corners and a 1 px top highlight. Children go into the content item.
// With reduced transparency, or without a backdrop, it is a solid rounded rectangle instead.
Item {
    id: panel

    property real radius: Theme.radiusPanel
    property real tintOpacity: Theme.glassOpacity
    property color tint: "#181622" // rgb(24,22,34); its alpha is ignored, tintOpacity applies
    property bool highlight: true
    default property alias content: contentItem.data

    // This panel's rect in Theme.glassSource, normalized to 0..1
    property rect region: Qt.rect(0, 0, 1, 1)

    readonly property Item _backdrop: Theme.glassSource && !Theme.reducedTransparency
                                      ? Theme.glassSource.blurredSource ?? null
                                      : null

    function updateRegion() {
        const src = Theme.glassSource
        if (!src || src.width <= 0 || src.height <= 0)
            return
        const r = panel.mapToItem(src, 0, 0, panel.width, panel.height)
        const x = r.x / src.width
        const y = r.y / src.height
        const w = r.width / src.width
        const h = r.height / src.height
        // skip no-op writes: called every frame, the effect must only be dirtied when the rect moves
        if (x !== region.x || y !== region.y || w !== region.width || h !== region.height)
            region = Qt.rect(x, y, w, h)
    }

    onXChanged: updateRegion()
    onYChanged: updateRegion()
    onWidthChanged: updateRegion()
    onHeightChanged: updateRegion()
    Component.onCompleted: updateRegion()

    Connections {
        target: Theme
        function onGlassSourceChanged() {
            panel.updateRegion()
        }
    }
    Connections {
        target: Theme.glassSource
        function onWidthChanged() {
            panel.updateRegion()
        }
        function onHeightChanged() {
            panel.updateRegion()
        }
    }
    // Ancestors can move the panel without touching its own x/y: re-map once per frame, before the
    // scene graph sync. It is a single mapToItem; the uniform only changes when the rect does.
    Connections {
        target: panel._backdrop ? panel.Window.window : null
        function onAfterAnimating() {
            panel.updateRegion()
        }
    }

    // Soft depth shadow under the pane: 0 24px 60px -28px rgba(0,0,0,.7)
    property bool shadow: true
    GlowHalo {
        anchors.fill: parent
        visible: panel.shadow
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: panel.radius
        spread: 60
        offsetY: 24
        shrink: 28
    }

    // Only instantiated with a backdrop: a ShaderEffect without a texture provider warns on every sync
    Loader {
        anchors.fill: parent
        active: panel._backdrop !== null
        sourceComponent: ShaderEffect {
            fragmentShader: "qrc:/flux/shaders/glass.frag.qsb"

            property variant source: panel._backdrop
            property rect region: panel.region
            property size size: Qt.size(width, height)
            property real radius: panel.radius
            property vector4d tint: Qt.vector4d(panel.tint.r, panel.tint.g, panel.tint.b, panel.tintOpacity)
            property real highlight: panel.highlight ? 1 : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: panel._backdrop === null
        radius: panel.radius
        color: "#17151F"
    }

    Item {
        id: contentItem
        anchors.fill: parent
    }
}
