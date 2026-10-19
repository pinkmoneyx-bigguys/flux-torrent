import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The pills along the top of the frameless window: logo, search (takes all free width), live speeds
// with the alternative-limits toggle, and the window buttons. Main.qml hands the window buttons and
// `interactiveItems` to QWindowKit; everything else in the bar drags the window.
Item {
    id: root

    // Plain properties bound to the session, so tests can drive them
    property real downloadRate: SessionFacade.downloadRate
    property real uploadRate: SessionFacade.uploadRate
    property bool altSpeedEnabled: SessionFacade.altSpeedEnabled

    readonly property alias searchField: searchInput
    readonly property alias altSpeedButton: altButton
    readonly property alias minimizeButton: minBtn
    readonly property alias maximizeButton: maxBtn
    readonly property alias closeButton: closeBtn
    // Clickable parts that must not drag the window; the last three are also the agent's system buttons
    readonly property list<Item> interactiveItems: [searchPill, altButton, minBtn, maxBtn, closeBtn]

    function focusSearch() {
        searchInput.forceActiveFocus(Qt.ShortcutFocusReason)
    }

    implicitHeight: 44

    // 34x32 capsule for minimize / maximize / close; `danger` turns red on hover (close)
    component WindowButton: AbstractButton {
        id: wb

        property string iconPath
        property bool danger: false
        readonly property bool _hot: danger && (hovered || pressed)

        implicitWidth: 34
        implicitHeight: 32
        // like native caption buttons: not in the Tab order
        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: wb.clicked()

        background: Rectangle {
            radius: height / 2
            color: wb._hot ? Qt.rgba(232 / 255, 72 / 255, 85 / 255, 0.9)
                           : Qt.rgba(1, 1, 1, wb.pressed ? 0.12 : wb.hovered ? 0.08 : 0)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                path: wb.iconPath
                size: 10
                strokeWidth: 3.12 // 1.3 px at 10 px, as in the mockup
                color: wb._hot ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.86)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.gap

        // --- Logo -------------------------------------------------------------------------------
        GlassPanel {
            objectName: "titleLogo"
            Layout.preferredHeight: 44
            Layout.preferredWidth: logoRow.implicitWidth + Theme.sp(2) + Theme.sp(4)
            radius: height / 2

            RowLayout {
                id: logoRow
                x: Theme.sp(2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Item {
                    implicitWidth: 30
                    implicitHeight: 30

                    GlowHalo {
                        anchors.fill: parent
                        color: Theme.accentAlpha(0.55)
                        spread: 10
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.accent
                    }
                    Icon {
                        anchors.centerIn: parent
                        path: Icons.logo
                        size: 16
                        strokeWidth: 2.6
                        color: Theme.bg
                    }
                }
                Text {
                    text: "Flux"
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.26
                    Accessible.ignored: true
                }
            }
        }

        // --- Search -----------------------------------------------------------------------------
        GlassPanel {
            id: searchPill
            objectName: "titleSearch"
            Layout.fillWidth: true
            Layout.minimumWidth: 220
            Layout.preferredHeight: 44
            radius: height / 2

            // a click anywhere on the pill puts the cursor into the field
            TapHandler {
                onTapped: root.focusSearch()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(4)
                anchors.rightMargin: Theme.sp(2)
                spacing: 10

                Icon {
                    path: Icons.search
                    size: 15
                    strokeWidth: 1.6
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                TextField {
                    id: searchInput
                    objectName: "titleSearchField"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    padding: 0
                    background: null
                    color: Theme.text
                    selectionColor: Theme.accentAlpha(0.35)
                    selectedTextColor: Theme.text
                    placeholderText: qsTr("Search torrents, files and commands")
                    placeholderTextColor: Theme.textFaint
                    font.family: Theme.fontText
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter
                    Accessible.name: qsTr("Search and commands")
                    Keys.onEscapePressed: {
                        text = ""
                        focus = false
                    }
                }
                Rectangle {
                    implicitWidth: hint.implicitWidth + 18
                    implicitHeight: hint.implicitHeight + 8
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: "Ctrl K"
                        color: Qt.rgba(1, 1, 1, 0.72)
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }
                }
            }
        }

        // --- Speeds and alternative limits ------------------------------------------------------
        GlassPanel {
            objectName: "titleSpeeds"
            Layout.preferredHeight: 44
            Layout.preferredWidth: speedRow.implicitWidth + Theme.sp(4) + 6
            radius: height / 2

            // the widest plausible speed, so the pill (and the search next to it) does not jitter
            TextMetrics {
                id: speedMetrics
                font.family: Theme.fontMono
                font.pixelSize: 13
                text: "↓ " + Format.speed(999.9 * 1024 * 1024)
            }

            RowLayout {
                id: speedRow
                x: Theme.sp(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    objectName: "titleDownRate"
                    Layout.minimumWidth: speedMetrics.advanceWidth
                    text: "↓ " + Format.speed(root.downloadRate)
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    Accessible.name: qsTr("Download speed %1").arg(Format.speed(root.downloadRate))
                }
                Text {
                    objectName: "titleUpRate"
                    Layout.minimumWidth: speedMetrics.advanceWidth
                    text: "↑ " + Format.speed(root.uploadRate)
                    color: Theme.upload
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    Accessible.name: qsTr("Upload speed %1").arg(Format.speed(root.uploadRate))
                }
                Item {
                    implicitWidth: 32
                    implicitHeight: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: root.altSpeedEnabled
                        color: Qt.rgba(1, 184 / 255, 107 / 255, 0.16)
                    }
                    IconButton {
                        id: altButton
                        objectName: "titleAltSpeed"
                        anchors.fill: parent
                        iconPath: Icons.turtle
                        iconColor: root.altSpeedEnabled ? Theme.warn : Qt.rgba(1, 1, 1, 0.86)
                        Accessible.name: qsTr("Alternative speed limits")
                        Accessible.checkable: true
                        Accessible.checked: root.altSpeedEnabled
                        onClicked: SessionFacade.altSpeedEnabled = !root.altSpeedEnabled
                    }
                }
            }
        }

        // --- Window buttons ---------------------------------------------------------------------
        GlassPanel {
            objectName: "titleWindowButtons"
            Layout.preferredHeight: 44
            Layout.preferredWidth: windowRow.implicitWidth + 12
            radius: height / 2

            Row {
                id: windowRow
                anchors.centerIn: parent
                spacing: 2

                WindowButton {
                    id: minBtn
                    text: qsTr("Minimize")
                    iconPath: Icons.minimize
                    onClicked: root.Window.window.showMinimized()
                }
                WindowButton {
                    id: maxBtn
                    readonly property bool maximized: root.Window.window
                                                      && root.Window.window.visibility === Window.Maximized
                    text: maximized ? qsTr("Restore") : qsTr("Maximize")
                    iconPath: Icons.maximize
                    onClicked: maximized ? root.Window.window.showNormal() : root.Window.window.showMaximized()
                }
                WindowButton {
                    id: closeBtn
                    text: qsTr("Close")
                    iconPath: Icons.close
                    danger: true
                    onClicked: root.Window.window.close()
                }
            }
        }
    }
}
