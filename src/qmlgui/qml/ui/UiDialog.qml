import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn Dialog / AlertDialog: modal card centred over a black/50 overlay. Content goes between the
// header (title, description) and the footer (`footer` children are right-aligned buttons).
Popup {
    id: root

    property string title
    property string description
    default property alias body: bodyColumn.data
    property alias footerItems: footerRow.data
    // Items on the left of the footer (secondary actions)
    property alias footerLeftItems: footerLeftRow.data
    property real preferredWidth: 512

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(preferredWidth, (parent ? parent.width : preferredWidth) - 32)
    padding: 24
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.5)
        Behavior on opacity {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: 150 }
        }
    }

    enter: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
    }

    background: Rectangle {
        radius: Theme.radiusPanel - 2
        color: Theme.glass ? "#17151F" : Theme.background
        border.width: 1
        border.color: Theme.border
    }

    contentItem: ColumnLayout {
        spacing: Theme.sp(4)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp(2)

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: 17
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }
            Text {
                visible: root.description !== ""
                Layout.fillWidth: true
                text: root.description
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                lineHeight: 1.3
                wrapMode: Text.Wrap
            }
        }

        ColumnLayout {
            id: bodyColumn
            Layout.fillWidth: true
            // a dialog given a height (a long list in it) shares it out here
            Layout.fillHeight: true
            spacing: Theme.sp(3)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp(2)
            spacing: Theme.sp(2)
            RowLayout {
                id: footerLeftRow
                spacing: Theme.sp(2)
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                id: footerRow
                spacing: Theme.sp(2)
            }
        }
    }
}
