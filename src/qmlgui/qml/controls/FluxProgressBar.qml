import QtQuick
import Flux

// A 6 px progress bar: `value` is 0..1 (clamped); `glow` adds a soft halo around the fill.
Item {
    id: root

    property real value: 0
    property color color: Theme.accent
    property bool glow: false

    readonly property alias fill: fillRect
    readonly property real _v: Math.max(0, Math.min(1, isNaN(value) ? 0 : value))

    implicitWidth: 160
    implicitHeight: 6

    Accessible.role: Accessible.ProgressBar
    Accessible.name: qsTr("Progress")
    Accessible.description: Math.round(_v * 100) + "%"

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    GlowHalo {
        anchors.fill: fillRect
        visible: root.glow && fillRect.width > 0
        color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.5)
        radius: height / 2
        spread: 8
    }

    Rectangle {
        id: fillRect
        width: root.width * root._v
        height: parent.height
        radius: Theme.radiusPill
        color: root.color
    }
}
