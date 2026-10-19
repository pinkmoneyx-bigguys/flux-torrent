import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The standard capsule button. `primary` is the accent call-to-action; otherwise a quiet glass pill.
// Pressing scales it to 0.97 (skipped with reduced motion).
AbstractButton {
    id: root

    property bool primary: false
    property string iconPath
    property string shortcutHint

    readonly property color _ink: primary ? "#08070D" : Theme.text

    implicitWidth: Math.max(implicitHeight, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: 36
    leftPadding: Theme.sp(4)
    rightPadding: Theme.sp(4)
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

    background: Item {
        property alias color: fill.color
        property alias radius: fill.radius

        GlowHalo {
            anchors.fill: parent
            visible: root.primary && root.enabled
            color: Theme.accentAlpha(0.55)
            radius: fill.radius
            spread: 12
            offsetY: 6
        }
        Rectangle {
            id: fill
            anchors.fill: parent
            radius: height / 2
            color: root.primary
                   ? (root.hovered ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
                   : Qt.rgba(1, 1, 1, root.pressed ? 0.12 : root.hovered ? 0.10 : 0.07)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        // inset top highlight; hugs the pill's curve by starting where the rounded corners end
        Rectangle {
            visible: root.primary
            x: fill.radius - Math.sqrt(Math.max(0, 2 * fill.radius - 1))
            width: parent.width - 2 * x
            height: 1
            color: Qt.rgba(1, 1, 1, 0.5)
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
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            spacing: Theme.sp(2)

            Icon {
                visible: root.iconPath !== ""
                path: root.iconPath
                color: root._ink
                size: 16
                strokeWidth: 1.8
            }
            Text {
                text: root.text
                visible: root.text !== ""
                color: root._ink
                font.family: Theme.fontText
                font.pixelSize: 14
                font.weight: root.primary ? Font.DemiBold : Font.Medium
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            Text {
                text: root.shortcutHint
                visible: root.shortcutHint !== ""
                color: root.primary ? Qt.rgba(8 / 255, 7 / 255, 13 / 255, 0.6) : Theme.textFaint
                font.family: Theme.fontMono
                font.pixelSize: 11
                wrapMode: Text.NoWrap
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
