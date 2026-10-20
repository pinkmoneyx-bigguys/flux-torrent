import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn Input (32 px) with an optional leading icon. `text` and `field` expose the editor.
Surface {
    id: root

    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias field: field
    property string iconPath
    // the × that empties the field
    property bool clearable: true
    signal accepted()

    kind: "field"
    focused: field.activeFocus
    radius: Theme.glass ? height / 2 : Theme.radiusCtl
    implicitWidth: 240
    implicitHeight: 32

    TapHandler {
        onTapped: field.forceActiveFocus(Qt.MouseFocusReason)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.iconPath !== "" ? 10 : 12
        anchors.rightMargin: 8
        spacing: Theme.sp(2)

        Icon {
            visible: root.iconPath !== ""
            path: root.iconPath
            size: 14
            strokeWidth: 2
            color: Theme.textDim
        }
        TextField {
            id: field
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 0
            background: null
            color: Theme.text
            selectionColor: "#3F3F46"
            selectedTextColor: Theme.text
            placeholderTextColor: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            verticalAlignment: TextInput.AlignVCenter
            Accessible.name: placeholderText
            onAccepted: root.accepted()
            Keys.onEscapePressed: event => {
                if (text !== "") {
                    text = ""
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }
        UiButton {
            visible: root.clearable && field.text !== ""
            size: "iconSm"
            variant: "ghost"
            iconPath: Icons.x
            implicitHeight: 22
            Accessible.name: qsTr("Clear")
            onClicked: field.text = ""
        }
    }
}
