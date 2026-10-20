import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn DropdownMenuItem: 32 px row, rounded-sm, accent fill on hover/keyboard focus, optional icon
// and shortcut hint; `destructive` paints it red.
MenuItem {
    id: root

    property string iconPath
    property string shortcut
    property bool destructive: false

    implicitWidth: 216
    implicitHeight: 32
    leftPadding: 8
    rightPadding: 8
    opacity: enabled ? 1 : 0.5

    readonly property color _fg: destructive ? Theme.error : Theme.text

    background: Rectangle {
        radius: Theme.radiusCtl - 2
        color: root.highlighted ? (root.destructive ? Theme.alpha(Theme.error, 0.15) : Theme.hover) : "transparent"
    }

    contentItem: RowLayout {
        spacing: Theme.sp(2)

        Icon {
            visible: root.iconPath !== ""
            path: root.iconPath
            size: 16
            strokeWidth: 1.75
            color: root.destructive ? Theme.error : Theme.textDim
        }
        Text {
            Layout.fillWidth: true
            text: root.text
            color: root._fg
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
        Text {
            visible: root.shortcut !== ""
            text: root.shortcut
            color: Theme.textFaint
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
        }
    }

    indicator: null
    arrow: null
}
