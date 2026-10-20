import QtQuick
import QtQuick.Layouts
import Flux

// A page with only a title and a one-line hint: the placeholder for sections not built yet.
// Default look: plain text centred on the content inset. Glass look: a frosted pane.
Surface {
    id: root

    property string title
    property string hint

    kind: Theme.glass ? "panel" : "chrome"
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
            font.pixelSize: Theme.glass ? 22 : 18
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.glass ? -0.44 : -0.36
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
            font.pixelSize: Theme.glass ? 14 : Theme.textSm
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
