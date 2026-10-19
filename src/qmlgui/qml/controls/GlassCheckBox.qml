import QtQuick
import QtQuick.Controls.Basic
import Flux

// An 18x18 check box: a quiet ring while off, an accent fill with glow and a check mark while on.
// Set Accessible.name to describe it.
AbstractButton {
    id: root

    checkable: true
    implicitWidth: 18
    implicitHeight: 18
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
        if (event.key === Qt.Key_Space)
            Qt.callLater(() => root._kbd = false)
    }
    onActiveFocusChanged: if (!activeFocus) _kbd = false

    readonly property alias mark: markIcon

    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: root.checked
    Accessible.onToggleAction: root.toggle()
    Accessible.onPressAction: root.toggle()

    background: Item {
        property alias color: fillRect.color

        GlowHalo {
            anchors.fill: parent
            visible: root.checked
            color: Theme.accentAlpha(0.55)
            radius: Theme.radiusSmall
            spread: 8
        }
        Rectangle {
            id: fillRect
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: root.checked ? Theme.accent : Qt.rgba(1, 1, 1, root.hovered ? 0.12 : 0.08)
            border.width: root.checked ? 0 : 1.5
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on color {
                enabled: !Theme.reducedMotion && !root._kbd
                ColorAnimation { duration: Theme.durFast }
            }
        }
        Rectangle {
            visible: root.visualFocus
            anchors.fill: parent
            anchors.margins: -4
            radius: Theme.radiusSmall + 4
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
        }
    }

    contentItem: Item {
        Icon {
            id: markIcon
            anchors.centerIn: parent
            path: Icons.check
            color: "#08070D"
            size: 12
            strokeWidth: 3
            opacity: root.checked ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reducedMotion && !root._kbd
                NumberAnimation { duration: Theme.durFast }
            }
        }
    }
}
