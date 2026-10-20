import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn Button. variant: "default" (primary), "outline", "secondary", "ghost", "destructive";
// size: "sm" (32 px), "default" (36 px), "icon" (32x32, needs Accessible.name), "iconSm" (28x28).
AbstractButton {
    id: root

    property string variant: "default"
    property string size: "sm"
    property string iconPath
    readonly property bool _iconOnly: size === "icon" || size === "iconSm"

    implicitHeight: size === "default" ? 36 : size === "iconSm" ? 28 : 32
    implicitWidth: _iconOnly ? implicitHeight : contentItem.implicitWidth + leftPadding + rightPadding
    leftPadding: _iconOnly ? 0 : (iconPath !== "" ? 10 : 12)
    rightPadding: _iconOnly ? 0 : 12
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: root.clicked()

    readonly property color _fg: variant === "default" ? Theme.primaryText
                               : variant === "destructive" ? "#FFFFFF"
                               : Theme.text

    background: Item {
        Rectangle {
            id: fill
            anchors.fill: parent
            radius: Theme.radiusCtl
            readonly property bool hot: root.hovered || root.pressed
            color: {
                switch (root.variant) {
                case "default":
                    return Theme.alpha(Theme.primary, fill.hot ? 0.9 : 1)
                case "destructive":
                    return Theme.alpha(Theme.error, fill.hot ? 0.75 : 0.6)
                case "secondary":
                    return Theme.alpha(Theme.muted, fill.hot ? 0.8 : 1)
                case "outline":
                    return Qt.rgba(1, 1, 1, fill.hot ? 0.075 : 0.045)
                default: // ghost
                    return fill.hot ? Theme.hover : Theme.alpha(Theme.hover, 0)
                }
            }
            border.width: root.variant === "outline" ? 1 : 0
            border.color: Theme.input
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        // focus-visible:ring-[3px] ring-ring/50
        Rectangle {
            visible: root.visualFocus
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radiusCtl + 3
            color: "transparent"
            border.width: 3
            border.color: Theme.alpha(Theme.ring, 0.5)
        }
    }

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Icon {
                visible: root.iconPath !== ""
                path: root.iconPath
                size: root.size === "iconSm" ? 14 : 16
                strokeWidth: 2
                color: root._fg
            }
            Text {
                visible: !root._iconOnly && root.text !== ""
                text: root.text
                color: root._fg
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: Font.Medium
                Accessible.ignored: true
            }
        }
    }
}
