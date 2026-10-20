import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn Select: an outline trigger showing the current option and a chevron; the options open in a
// menu with a check on the current one. `model`: [{key, label, disabled}] (disabled: shown, not choosable).
AbstractButton {
    id: root

    property var model: []
    property string currentKey
    property string iconPath
    signal activated(string key)

    readonly property string currentLabel: {
        for (const o of model) {
            if (o.key === currentKey)
                return o.label
        }
        return ""
    }

    implicitHeight: 32
    implicitWidth: Math.max(140, row.implicitWidth + 24)
    leftPadding: 12
    rightPadding: 10
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : 0.5

    Accessible.role: Accessible.ComboBox
    Accessible.name: text
    Accessible.description: currentLabel
    Accessible.onPressAction: root.clicked()

    onClicked: menu.popup(root, 0, root.height + 4)
    Keys.onDownPressed: menu.popup(root, 0, root.height + 4)

    background: Item {
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusCtl
            color: Qt.rgba(1, 1, 1, root.hovered || menu.visible ? 0.075 : 0.045)
            border.width: 1
            border.color: menu.visible ? Theme.ring : Theme.input
        }
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

    contentItem: RowLayout {
        id: row
        spacing: Theme.sp(2)
        Icon {
            visible: root.iconPath !== ""
            path: root.iconPath
            size: 14
            strokeWidth: 2
            color: Theme.textDim
        }
        Text {
            Layout.fillWidth: true
            text: root.currentLabel
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
        Icon {
            path: Icons.chevronDown
            size: 14
            strokeWidth: 2
            color: Theme.textDim
        }
    }

    UiMenu {
        id: menu
        implicitWidth: Math.max(root.width, 180)

        Instantiator {
            model: root.model
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)

            UiMenuItem {
                required property var modelData
                text: modelData.label
                enabled: !(modelData.disabled ?? false)
                iconPath: modelData.key === root.currentKey ? Icons.check : ""
                leftPadding: modelData.key === root.currentKey ? 8 : 32
                onTriggered: {
                    root.currentKey = modelData.key
                    root.activated(modelData.key)
                }
            }
        }
    }
}
