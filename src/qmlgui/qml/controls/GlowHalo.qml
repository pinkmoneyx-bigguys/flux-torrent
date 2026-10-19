import QtQuick
import QtQuick.Effects
import Flux

// A soft glow / drop shadow under the item it decorates (anchors.fill: parent, placed before the item's
// own visuals). A real gaussian-like falloff via RectangularShadow (an SDF shader, no offscreen pass).
Item {
    id: root

    property color color: Theme.accent
    property real radius: height / 2
    property real spread: 12       // blur reach beyond the item, in px
    property real offsetY: 0       // shifts the glow down (drop-shadow style)
    property real shrink: 0        // pulls the shadow in from every edge (CSS negative spread)
    property real intensity: 1     // multiplies the colour's alpha

    visible: intensity > 0 && color.a > 0

    RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        blur: root.spread
        spread: -root.shrink
        offset.y: root.offsetY
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, Math.min(1, root.color.a * root.intensity))
    }
}
