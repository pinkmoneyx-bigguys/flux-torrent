import QtQuick
import QtQuick.Layouts
import Flux

// A titled card of SettingRows separated by 1 px lines (shadcn settings form)
ColumnLayout {
    id: group

    property string title
    property string description
    default property alias rows: column.data

    Layout.fillWidth: true
    spacing: Theme.sp(3)

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: group.title !== ""
        Text {
            text: group.title
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textBase
            font.weight: Font.DemiBold
        }
        Text {
            visible: group.description !== ""
            Layout.fillWidth: true
            text: group.description
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            wrapMode: Text.Wrap
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: column.implicitHeight
        radius: Theme.radiusCtl + 2
        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
        border.width: 1
        border.color: Theme.border

        Column {
            id: column
            width: parent.width
        }
    }
}
