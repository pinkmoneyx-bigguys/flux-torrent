import QtQuick
import QtQuick.Controls.Basic
import Flux

// shadcn Checkbox: 16 px, rounded 4, primary fill when checked. `partial` draws a dash (some selected).
AbstractButton {
    id: root

    property bool partial: false

    checkable: true
    implicitWidth: 16
    implicitHeight: 16
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    // as a click does: toggle() alone leaves out the toggled() that the settings commit on
    Accessible.onPressAction: {
        root.toggle()
        root.toggled()
    }

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: 4
            color: root.checked || root.partial ? Theme.primary : Theme.inputFill
            border.width: 1
            border.color: root.checked || root.partial ? Theme.primary : Theme.input
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
            Behavior on border.color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        Rectangle {
            visible: root.visualFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: 7
            color: "transparent"
            border.width: 3
            border.color: Theme.alpha(Theme.ring, 0.5)
        }
    }
    contentItem: Item {
        Icon {
            readonly property bool on: root.checked || root.partial
            anchors.centerIn: parent
            visible: opacity > 0
            opacity: on ? 1 : 0
            scale: on ? 1 : 0.6
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast }
            }
            Behavior on scale {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutBack }
            }
            path: root.checked ? Icons.check : Icons.minus
            size: 14
            strokeWidth: 2.5
            color: Theme.primaryText
        }
    }
}
