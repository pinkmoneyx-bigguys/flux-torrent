import QtQuick
import QtQuick.Controls.Basic
import Flux

// A 44x26 on/off switch with a 20 px white knob; the accent track glows while on.
// Exposed as a check box to assistive technology. Set Accessible.name to describe it.
AbstractButton {
    id: root

    readonly property alias track: trackRect
    readonly property alias knob: knobRect

    checkable: true
    implicitWidth: 44
    implicitHeight: 26
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    // Space activates without animation: keyboard actions never animate. The flag stays up until the
    // key-up event has been fully handled (the toggle happens in it), then drops on the next turn.
    property bool _kbd: false
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat)
            root._kbd = true
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Space && !event.isAutoRepeat)
            Qt.callLater(() => root._kbd = false)
    }
    onActiveFocusChanged: if (!activeFocus) _kbd = false

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggle()
    Accessible.onPressAction: root.toggle()

    background: Item {
        GlowHalo {
            anchors.fill: parent
            visible: root.checked
            color: Theme.accentAlpha(0.5)
            radius: height / 2
            spread: 10
        }
        Rectangle {
            id: trackRect
            anchors.fill: parent
            radius: height / 2
            color: root.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.14)
            Behavior on color {
                enabled: !Theme.reducedMotion && !root._kbd
                ColorAnimation { duration: Theme.durFast }
            }
        }
        Rectangle { // inset hairline while off
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.checked ? 0 : 0.06)
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
        Rectangle {
            id: knobRect
            width: 20
            height: 20
            radius: 10
            y: 3
            x: root.checked ? root.width - 3 - width : 3
            color: "white"
            Behavior on x {
                enabled: !Theme.reducedMotion && !root._kbd
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Theme.easing.type
                    easing.bezierCurve: Theme.easing.bezierCurve
                }
            }
        }
    }
}
