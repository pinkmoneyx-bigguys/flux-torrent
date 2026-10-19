import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Flux

// The colourful backdrop of the window. It is drawn as is, and blurred once into a static texture
// (`blurredSource`) that every GlassPanel samples. The blur is recomputed only after the size or the
// accent changes, debounced, never per frame. Assign the instance to Theme.glassSource.
Item {
    id: root
    anchors.fill: parent

    // Static texture with the blurred backdrop, in this item's coordinates
    readonly property Item blurredSource: blurredTexture
    // How many times the blur was recomputed (for tests)
    property int rebuildCount: 0

    // A soft radial blob: `color` in the center fading to transparent at 72 % of the radius
    component Blob: Shape {
        id: blob
        property real size
        property color color
        width: size
        height: size
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: blob.size / 2
                centerY: blob.size / 2
                centerRadius: blob.size / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: blob.color }
                GradientStop { position: 0.72; color: Qt.rgba(blob.color.r, blob.color.g, blob.color.b, 0) }
            }
            PathRectangle { width: blob.size; height: blob.size }
        }
    }

    Item {
        id: scene
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }
        Blob { // violet
            size: 900
            color: Qt.rgba(122 / 255, 84 / 255, 1, 0.6)
            x: -0.12 * root.width
            y: -0.30 * root.height
        }
        Blob { // pink
            size: 760
            color: Qt.rgba(1, 79 / 255, 216 / 255, 0.3)
            x: root.width - 0.14 * root.width - size
            y: -0.26 * root.height
        }
        Blob { // mint: follows the accent
            size: 1100
            color: Theme.accentAlpha(0.42)
            x: root.width + 0.14 * root.width - size
            y: root.height + 0.34 * root.height - size
        }
        Blob { // blue
            size: 900
            color: Qt.rgba(47 / 255, 123 / 255, 1, 0.38)
            x: 0.12 * root.width
            y: root.height + 0.40 * root.height - size
        }
    }

    // Rendered only through blurredTexture, which is not live: the blur runs when it is regrabbed
    MultiEffect {
        id: blur
        anchors.fill: parent
        source: scene
        visible: false
        autoPaddingEnabled: false // keep the edges opaque: sample the clamped border, not transparency
        blurEnabled: true
        blur: 1.0
        blurMax: 64
    }

    // Also the visible window background: the colour shows everywhere around the panels, and each
    // GlassPanel darkens and tints its own region of the same texture — glass over a lit backdrop.
    ShaderEffectSource {
        id: blurredTexture
        anchors.fill: parent
        sourceItem: blur
        live: false
    }

    Timer {
        id: rebuildTimer
        interval: 120
        repeat: false
        onTriggered: {
            blurredTexture.scheduleUpdate()
            ++root.rebuildCount
        }
    }

    onWidthChanged: rebuildTimer.restart()
    onHeightChanged: rebuildTimer.restart()

    Connections {
        target: Theme
        function onAccentChanged() {
            rebuildTimer.restart()
        }
    }
}
