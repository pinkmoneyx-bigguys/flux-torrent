import QtQuick
import QtQuick.Layouts
import Flux

// A glass page with only a title and a one-line hint: the placeholder for sections not built yet.
GlassPanel {
    id: root

    property string title
    property string hint

    radius: Theme.radiusPanel

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.sp(6), 560)
        spacing: Theme.sp(2)

        Text {
            Layout.fillWidth: true
            text: root.title
            color: Theme.text
            font.family: Theme.fontDisplay
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.letterSpacing: -0.44
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Text {
            Layout.fillWidth: true
            text: root.hint
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
