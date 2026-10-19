import QtQuick
import QtQuick.Controls.Basic
import Flux

// A round 32x32 icon-only button. It has no visible text, so the user must set Accessible.name
// (a console warning reminds them).
AbstractButton {
    id: root

    property string iconPath
    property real iconSize: 16
    property real iconStrokeWidth: 1.5
    property color iconColor: Qt.rgba(1, 1, 1, 0.76)

    implicitWidth: 32
    implicitHeight: 32
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    scale: pressed && !Theme.reducedMotion ? 0.97 : 1.0
    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation {
            duration: Theme.durPress
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: root.clicked()

    Component.onCompleted: {
        if (root.Accessible.name === "")
            console.warn("IconButton without Accessible.name: icon-only buttons need an accessible name")
    }

    background: Item {
        property alias radius: fill.radius

        Rectangle {
            id: fill
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, root.pressed ? 0.12 : root.hovered ? 0.08 : 0)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        Rectangle {
            visible: root.visualFocus
            anchors.fill: parent
            anchors.margins: -4
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
        }
    }

    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            path: root.iconPath
            color: root.iconColor
            size: root.iconSize
            strokeWidth: root.iconStrokeWidth
        }
    }
}
