import QtQuick
import Flux

// A cheap soft glow / drop shadow: a few stacked, growing, translucent rounded rectangles instead of a
// blur pass. Fill the item it decorates (anchors.fill: parent) and put it before the item's own visuals.
Item {
    id: root

    property color color: Theme.accent
    property real radius: height / 2
    property real spread: 12       // how far the halo reaches beyond the item, in px
    property real offsetY: 0       // shifts the glow down (drop-shadow style)
    property real intensity: 1     // multiplies the alpha of every layer
    readonly property int layers: 6

    visible: intensity > 0 && color.a > 0

    Repeater {
        model: root.layers

        Rectangle {
            required property int index
            readonly property real grow: root.spread * (index + 1) / root.layers

            x: -grow
            y: -grow + root.offsetY
            width: root.width + 2 * grow
            height: root.height + 2 * grow
            radius: root.radius + grow
            color: Qt.rgba(root.color.r, root.color.g, root.color.b, root.color.a * 0.13 * root.intensity)
        }
    }
}
