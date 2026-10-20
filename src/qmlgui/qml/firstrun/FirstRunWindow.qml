import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import Flux

// The first-run dialog: offers to carry the user's torrents and settings over from qBittorrent.
// It is only a view. The C++ side (migration/firstrun.cpp) fills in the properties below and reacts to
// migrateRequested() / startFreshRequested(); closing the window without choosing quits the application.
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

    readonly property int _margin: Theme.sp(6)
    readonly property int _pad: Theme.sp(7)

    title: "Flux Torrent"
    color: Theme.bg
    visible: true
    // a dialog: fixed size, as tall as its content
    readonly property int _width: 600
    readonly property int _height: panel.height + 2 * _margin
    width: _width
    height: _height
    minimumWidth: _width
    maximumWidth: _width
    minimumHeight: _height
    maximumHeight: _height

    Component.onCompleted: {
        Theme.glassSource = backdrop
        migrateButton.forceActiveFocus()
    }

    // A disabled button cannot hold the focus: hand it to the one that still works
    onQbtRunningChanged: {
        if (qbtRunning && migrateButton.activeFocus)
            startFreshButton.forceActiveFocus()
    }

    GlassBackground {
        id: backdrop
    }

    // dims the backdrop under the dialog, like the scrim behind the mockup's dialogs
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(6 / 255, 5 / 255, 10 / 255, 0.45)
    }

    GlassPanel {
        id: panel
        x: root._margin
        y: root._margin
        width: root._width - 2 * root._margin
        height: content.implicitHeight + 2 * root._pad
        radius: 30
        tint: "#1E1B2C"
        tintOpacity: 0.58

        NumberAnimation on opacity {
            from: 0
            to: 1
            duration: Theme.durMed
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
            running: !Theme.reducedMotion
        }
        NumberAnimation on scale {
            from: 0.97
            to: 1
            duration: Theme.durMed
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
            running: !Theme.reducedMotion
        }

        ColumnLayout {
            id: content
            x: root._pad
            y: root._pad
            width: parent.width - 2 * root._pad
            spacing: Theme.sp(4)

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(4)

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignTop
                    radius: 15
                    color: Theme.accentAlpha(0.16)

                    Icon {
                        anchors.centerIn: parent
                        path: Icons.moveTo
                        color: Theme.accent
                        size: 20
                        strokeWidth: 1.6
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp(1)

                    Text {
                        objectName: "title"
                        Layout.fillWidth: true
                        text: qsTr("Migrate your torrents from qBittorrent?")
                        color: Theme.text
                        font.family: Theme.fontDisplay
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.38
                        wrapMode: Text.Wrap
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Text {
                        objectName: "count"
                        Layout.fillWidth: true
                        // %n: the Russian form is the same for every count, so it needs no declension
                        // -1: the torrent database could not be read, so the number is not known
                        text: root.torrentCount >= 0
                              ? qsTr("%n torrent(s) in your qBittorrent profile", "", root.torrentCount)
                              : qsTr("The torrents and settings of your qBittorrent profile")
                        color: Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }
                }
            }

            // After the move Flux owns the torrents: running both on them would corrupt the resume data
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(3)

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 6
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: Theme.warn
                }
                Text {
                    objectName: "warning"
                    Layout.fillWidth: true
                    text: qsTr("After the move, Flux manages these torrents. Don't run them in qBittorrent at the same time.")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }
            }

            Text {
                objectName: "runningNote"
                Layout.fillWidth: true
                visible: root.qbtRunning
                text: qsTr("Close qBittorrent to migrate your torrents")
                color: Theme.warn
                font.family: Theme.fontText
                font.pixelSize: 14
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
                    font.pixelSize: 14
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
                Layout.topMargin: Theme.sp(1)
                spacing: Theme.sp(2)

                Item {
                    Layout.fillWidth: true
                }
                PillButton {
                    id: startFreshButton
                    objectName: "startFreshButton"
                    text: qsTr("Start fresh")
                    implicitHeight: 42
                    fontSize: 13
                    enabled: !root.busy
                    onClicked: root.startFreshRequested()
                }
                PillButton {
                    id: migrateButton
                    objectName: "migrateButton"
                    text: root.busy ? qsTr("Migrating…") : qsTr("Migrate")
                    primary: true
                    implicitHeight: 42
                    fontSize: 13
                    enabled: !root.qbtRunning && !root.busy
                    onClicked: root.migrateRequested()
                }
            }
        }
    }
}
