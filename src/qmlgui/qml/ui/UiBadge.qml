import QtQuick
import QtQuick.Layouts
import Flux

// shadcn Badge. variant: "outline" (border, muted text), "secondary" (muted fill), "default" (primary).
// `dotColor` adds a status dot before the text.
Rectangle {
    id: root

    property string text
    property string variant: "outline"
    property color dotColor: "transparent"

    implicitWidth: row.implicitWidth + 2 * 8
    implicitHeight: 22
    radius: height / 2
    color: variant === "secondary" ? Theme.muted : variant === "default" ? Theme.primary : "transparent"
    border.width: variant === "outline" ? 1 : 0
    border.color: Theme.border

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: root.dotColor.a > 0
            implicitWidth: 6
            implicitHeight: 6
            radius: 3
            color: root.dotColor
        }
        Text {
            text: root.text
            color: root.variant === "default" ? Theme.primaryText : root.variant === "outline" ? Theme.textDim : Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
            font.weight: Font.Medium
        }
    }
}
