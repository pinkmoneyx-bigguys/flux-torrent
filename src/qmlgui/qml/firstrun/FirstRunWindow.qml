import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import Flux

// The first-run dialog: offers to carry the user's torrents and settings over from qBittorrent.
// It is only a view. The C++ side (migration/firstrun.cpp) fills in the properties below and reacts to
// migrateRequested() / startFreshRequested(); closing the window without choosing quits the application.
// Drawn like the app's dialogs (UiDialog): the window is the card, buttons on the right of the footer.
Window {
    id: root

    // Torrents found in the qBittorrent profile, -1 if unknown
    property int torrentCount: 0
    // qBittorrent is running: its torrents cannot be moved safely until it is closed
    property bool qbtRunning: false
    // The copy is in progress
    property bool busy: false
    // "" | "target-not-empty" | "failed"
    property string errorCode: ""
    // The technical reason of a "failed" transfer
    property string errorDetail: ""

    signal migrateRequested()
    signal startFreshRequested()

    readonly property alias migrateButton: migrateButton
    readonly property alias startFreshButton: startFreshButton

    readonly property int _pad: 24

    title: "Flux Torrent"
    color: Theme.background
    visible: true
    // a dialog: fixed size, as tall as its content
    readonly property int _width: 520
    readonly property int _height: content.implicitHeight + 2 * _pad
    width: _width
    height: _height
    minimumWidth: _width
    maximumWidth: _width
    minimumHeight: _height
    maximumHeight: _height

    Component.onCompleted: migrateButton.forceActiveFocus()

    // A disabled button cannot hold the focus: hand it to the one that still works
    onQbtRunningChanged: {
        if (qbtRunning && migrateButton.activeFocus)
            startFreshButton.forceActiveFocus()
    }

    // the window's colour as an item too, so a grab of the content shows it
    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    ColumnLayout {
        id: content
        x: root._pad
        y: root._pad
        width: root._width - 2 * root._pad
        spacing: Theme.sp(4)

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: 150
            running: !Theme.reducedMotion
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp(3)

            // the Flux mark on a tile, as in the title bar
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                radius: Theme.radiusCtl
                color: Theme.muted
                border.width: 1
                border.color: Theme.border

                Icon {
                    anchors.centerIn: parent
                    path: Icons.logo
                    color: Theme.text
                    size: 20
                    strokeWidth: 2.2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(1)

                Text {
                    objectName: "title"
                    Layout.fillWidth: true
                    // no torrents: only the settings are carried over
                    text: root.torrentCount === 0 ? qsTr("Carry your settings over from qBittorrent?")
                                                  : qsTr("Migrate your torrents from qBittorrent?")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                Text {
                    objectName: "count"
                    Layout.fillWidth: true
                    // %n: the Russian form is the same for every count, so it needs no declension
                    // -1: the torrent database could not be read, so the number is not known
                    text: root.torrentCount > 0
                          ? qsTr("%n torrent(s) in your qBittorrent profile", "", root.torrentCount)
                          : root.torrentCount === 0
                            ? qsTr("Your qBittorrent profile has no torrents: its settings and RSS feeds come along")
                            : qsTr("The torrents and settings of your qBittorrent profile")
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    lineHeight: 1.3
                    wrapMode: Text.Wrap
                }
            }
        }

        // After the move Flux owns the torrents: running both on them would corrupt the resume data
        Rectangle {
            visible: root.torrentCount !== 0
            Layout.fillWidth: true
            implicitHeight: warningRow.implicitHeight + 2 * Theme.sp(3)
            radius: Theme.radiusCtl
            color: Theme.alpha(Theme.warn, 0.06)
            border.width: 1
            border.color: Theme.alpha(Theme.warn, 0.28)

            RowLayout {
                id: warningRow
                anchors.fill: parent
                anchors.margins: Theme.sp(3)
                spacing: Theme.sp(3)

                Icon {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 1
                    path: Icons.alert
                    color: Theme.warn
                    size: 16
                }
                Text {
                    objectName: "warning"
                    Layout.fillWidth: true
                    text: qsTr("After the move, Flux manages these torrents. Don't run them in qBittorrent at the same time.")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    lineHeight: 1.3
                    wrapMode: Text.Wrap
                }
            }
        }

        Text {
            objectName: "runningNote"
            Layout.fillWidth: true
            visible: root.qbtRunning
            text: qsTr("Close qBittorrent to migrate your torrents")
            color: Theme.warn
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            font.weight: Font.Medium
            wrapMode: Text.Wrap
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.errorCode !== ""
            spacing: Theme.sp(1)

            Text {
                objectName: "errorText"
                Layout.fillWidth: true
                text: root.errorCode === "target-not-empty"
                      ? qsTr("Flux already has torrents of its own, so nothing was moved. Start fresh to keep them.")
                      : qsTr("The transfer did not finish. Your qBittorrent profile was not touched.")
                color: Theme.error
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: Font.Medium
                wrapMode: Text.Wrap
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }
            Text {
                objectName: "errorDetail"
                Layout.fillWidth: true
                visible: root.errorDetail !== ""
                text: root.errorDetail
                color: Theme.textFaint
                font.family: Theme.fontMono
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.sp(2)
            spacing: Theme.sp(2)

            Item {
                Layout.fillWidth: true
            }
            UiButton {
                id: startFreshButton
                objectName: "startFreshButton"
                variant: "outline"
                size: "default"
                text: qsTr("Start fresh")
                enabled: !root.busy
                onClicked: root.startFreshRequested()
            }
            UiButton {
                id: migrateButton
                objectName: "migrateButton"
                size: "default"
                text: root.busy ? qsTr("Migrating…") : qsTr("Migrate")
                enabled: !root.qbtRunning && !root.busy
                onClicked: root.migrateRequested()
            }
        }
    }
}
