import QtQuick
import QtQuick.Controls.Basic
import Flux

// shadcn Switch: 32x18 track, primary when on, input colour when off; the thumb slides
AbstractButton {
    id: root

    checkable: true
    implicitWidth: 32
    implicitHeight: 18
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

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
            radius: height / 2
            color: root.checked ? Theme.primary : Qt.rgba(1, 1, 1, 0.18)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        Rectangle {
            visible: root.visualFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 3
            border.color: Theme.alpha(Theme.ring, 0.5)
        }
    }
    contentItem: Item {
        Rectangle {
            width: 14
            height: 14
            radius: 7
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: root.checked ? Theme.primaryText : Theme.text
            Behavior on x {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
            }
        }
    }
}
