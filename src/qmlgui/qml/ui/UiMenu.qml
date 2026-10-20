import QtQuick
import QtQuick.Controls.Basic
import Flux

// shadcn DropdownMenu / ContextMenu: popover surface, 1 px border, rounded-md, p-1. Fill it with
// UiMenuItem and MenuSeparator.
Menu {
    id: root

    padding: 4
    implicitWidth: 224
    margins: 8
    modal: false

    enter: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 120; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 }
    }

    background: Rectangle {
        implicitWidth: root.implicitWidth
        radius: Theme.radiusCtl
        color: Theme.popover
        border.width: 1
        border.color: Theme.border

        Rectangle { // shadow-md
            z: -1
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: -6
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            radius: parent.radius + 2
            color: Qt.rgba(0, 0, 0, 0.35)
        }
    }

    delegate: UiMenuItem {}
}
