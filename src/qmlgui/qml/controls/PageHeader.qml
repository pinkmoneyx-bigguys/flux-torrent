import QtQuick
import QtQuick.Layouts
import Flux

// The 48 px bar at the top of a page (shadcn SiteHeader): the title on the left, then `leading` items
// (a filter field), actions on the right (children go into the action row), a 1 px border underneath.
Item {
    id: root

    property string title
    property string subtitle
    default property alias actions: actionRow.data
    property alias leading: leadingRow.data
    // the line under the bar (off when a table header right below draws its own)
    property bool bordered: true

    implicitHeight: 48

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp(6)
        anchors.rightMargin: Theme.sp(4)
        spacing: Theme.sp(2)

        Text {
            text: root.title
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: 15
            font.weight: Font.Medium
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Rectangle {
            visible: root.subtitle !== ""
            Layout.preferredWidth: 1
            Layout.preferredHeight: 16
            Layout.leftMargin: Theme.sp(1)
            Layout.rightMargin: Theme.sp(1)
            color: Theme.border
        }
        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
        }
        RowLayout {
            id: leadingRow
            Layout.leftMargin: children.length > 0 ? Theme.sp(3) : 0
            spacing: Theme.sp(2)
        }
        Item {
            Layout.fillWidth: true
        }
        RowLayout {
            id: actionRow
            spacing: Theme.sp(2)
        }
    }

    Rectangle {
        visible: root.bordered
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.border
    }
}
