import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The two looks as radio cards with a small preview each; picking one sets UiSettings.style
RowLayout {
    id: picker

    // One choice of the look (shadcn "appearance" radio card): a preview, the name under it
    component StyleCard: AbstractButton {
        id: card

        property string styleId
        property string description
        readonly property bool current: UiSettings.style === styleId
        default property alias preview: previewBox.data

        implicitWidth: 236
        implicitHeight: col.implicitHeight
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        checkable: false

        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.description: description
        Accessible.checked: current
        Accessible.onPressAction: card.clicked()

        onClicked: UiSettings.style = styleId

        contentItem: ColumnLayout {
            id: col
            spacing: Theme.sp(2)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 148
                radius: Theme.radiusCtl + 2
                color: "transparent"
                border.width: 2
                border.color: card.current ? Theme.primary : card.hovered ? Theme.alpha(Theme.text, 0.25) : Theme.muted
                Behavior on border.color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }

                Item {
                    id: previewBox
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                }
                Rectangle {
                    visible: card.visualFocus
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: parent.radius + 4
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.alpha(Theme.ring, 0.6)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(2)

                // radio indicator
                Rectangle {
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    color: Theme.inputFill
                    border.width: 1
                    border.color: card.current ? Theme.primary : Theme.input
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        visible: card.current
                        color: Theme.primary
                    }
                }
                Text {
                    text: card.text
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium
                }
            }
            Text {
                Layout.fillWidth: true
                text: card.description
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                wrapMode: Text.Wrap
            }
        }
    }

    // A thin placeholder line in the previews (shadcn skeleton bars)
    component Bar: Rectangle {
        height: 6
        radius: 3
    }

    spacing: Theme.sp(4)
    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Theme")

    StyleCard {
        objectName: "styleDefault"
        styleId: "default"
        text: qsTr("Default")
        description: qsTr("Calm neutral surfaces with clear borders. Easy on the eyes for long sessions.")

        // flat preview: chrome, sidebar rows and an inset with table rows
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusCtl - 2
            color: "#171717"

            Column {
                x: 8; y: 10
                spacing: 6
                Bar { width: 40; color: "#404040" }
                Bar { width: 44; color: "#2E2E2E" }
                Bar { width: 36; color: "#2E2E2E" }
                Bar { width: 42; color: "#2E2E2E" }
            }
            Rectangle {
                x: 60; y: 6
                width: parent.width - 66
                height: parent.height - 12
                radius: 6
                color: "#0A0A0A"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)

                Column {
                    x: 10; y: 12
                    spacing: 9
                    Bar { width: 70; color: "#3A3A3A" }
                    Repeater {
                        model: 4
                        Row {
                            spacing: 8
                            Bar { width: 56; color: "#262626" }
                            Bar { width: 34; color: index % 2 ? "#4ADE80" : "#60A5FA"; opacity: 0.8 }
                        }
                    }
                }
            }
        }
    }

    StyleCard {
        objectName: "styleGlass"
        styleId: "glass"
        text: qsTr("Liquid Glass")
        description: qsTr("Frosted glass panes over a soft colour backdrop.")

        // glass preview: coloured blobs under translucent rounded panes
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusCtl - 2
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#2A1F57" }
                GradientStop { position: 0.55; color: "#14122A" }
                GradientStop { position: 1; color: "#0F3B33" }
            }

            Rectangle {
                x: 6; y: 6
                width: 50
                height: parent.height - 12
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Column {
                    x: 7; y: 10
                    spacing: 6
                    Bar { width: 36; color: Qt.rgba(1, 1, 1, 0.28) }
                    Bar { width: 30; color: Qt.rgba(1, 1, 1, 0.14) }
                    Bar { width: 34; color: Qt.rgba(1, 1, 1, 0.14) }
                }
            }
            Rectangle {
                x: 62; y: 6
                width: parent.width - 68
                height: parent.height - 12
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Column {
                    x: 10; y: 12
                    spacing: 9
                    Bar { width: 70; color: Qt.rgba(1, 1, 1, 0.3) }
                    Repeater {
                        model: 4
                        Row {
                            spacing: 8
                            Bar { width: 56; color: Qt.rgba(1, 1, 1, 0.12) }
                            Bar { width: 34; color: "#3EF0B0"; opacity: 0.8 }
                        }
                    }
                }
            }
        }
    }
}
