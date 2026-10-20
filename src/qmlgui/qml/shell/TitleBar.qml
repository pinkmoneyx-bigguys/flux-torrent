import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The top of the frameless window: logo, search (takes all free width), live speeds with the
// alternative-limits toggle, and the window buttons. Default look: one flat strip on the window chrome,
// the logo over the sidebar and Windows-style caption buttons. Glass look: separate frosted pills.
// Main.qml hands the window buttons and `interactiveItems` to QWindowKit; the rest drags the window.
Item {
    id: root

    // Plain properties bound to the session, so tests can drive them
    property real downloadRate: SessionFacade.downloadRate
    property real uploadRate: SessionFacade.uploadRate
    property bool altSpeedEnabled: SessionFacade.altSpeedEnabled
    // Default look: the logo block is as wide as the sidebar under it
    property real logoWidth: 236

    readonly property alias searchField: searchInput
    readonly property alias altSpeedButton: altButton
    readonly property alias minimizeButton: minBtn
    readonly property alias maximizeButton: maxBtn
    readonly property alias closeButton: closeBtn
    // Clickable parts that must not drag the window; the last three are also the agent's system buttons
    readonly property list<Item> interactiveItems: [searchPill, altButton, minBtn, maxBtn, closeBtn]

    // The search pill opens the command palette (Main shows it)
    signal commandsRequested()
    function focusSearch() {
        commandsRequested()
    }

    implicitHeight: 44

    // Caption button. Glass: a 34x32 capsule. Default: a flat 46 px wide Windows caption button that
    // fills the strip height. `danger` turns red on hover (close).
    component WindowButton: AbstractButton {
        id: wb

        property string iconPath
        property bool danger: false
        readonly property bool _hot: danger && (hovered || pressed)

        implicitWidth: Theme.glass ? 34 : 46
        implicitHeight: Theme.glass ? 32 : root.height
        // like native caption buttons: not in the Tab order
        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: wb.clicked()

        background: Rectangle {
            radius: Theme.glass ? height / 2 : 0
            color: wb._hot ? (Theme.glass ? Qt.rgba(232 / 255, 72 / 255, 85 / 255, 0.9) : "#C42B1C")
                           : Qt.rgba(1, 1, 1, wb.pressed ? (Theme.glass ? 0.12 : 0.06) : wb.hovered ? (Theme.glass ? 0.08 : 0.08) : 0)
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
                strokeWidth: Theme.glass ? 3.12 : 2.4 // 1.3 px / 1 px at 10 px
                color: wb._hot ? "#FFFFFF" : Theme.glass ? Qt.rgba(1, 1, 1, 0.86) : Theme.text
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.glass ? Theme.gap : 0

        // --- Logo -------------------------------------------------------------------------------
        Surface {
            objectName: "titleLogo"
            kind: "chrome"
            Layout.preferredHeight: 44
            Layout.preferredWidth: Theme.glass ? logoRow.implicitWidth + Theme.sp(2) + Theme.sp(4) : root.logoWidth
            radius: height / 2

            RowLayout {
                id: logoRow
                x: Theme.glass ? Theme.sp(2) : Theme.sp(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.glass ? 10 : Theme.sp(2)

                Item {
                    implicitWidth: Theme.glass ? 30 : 24
                    implicitHeight: implicitWidth

                    GlowHalo {
                        anchors.fill: parent
                        visible: Theme.glass
                        color: Theme.accentAlpha(0.55)
                        spread: 10
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.glass ? width / 2 : Theme.radiusSmall
                        color: Theme.primary
                    }
                    Icon {
                        anchors.centerIn: parent
                        path: Icons.logo
                        size: Theme.glass ? 16 : 14
                        strokeWidth: Theme.glass ? 2.6 : 2.4
                        color: Theme.primaryText
                    }
                }
                Text {
                    text: "Flux"
                    color: Theme.text
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.glass ? 13 : Theme.textBase
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.glass ? -0.26 : -0.2
                    Accessible.ignored: true
                }
            }
        }

        // --- Search -----------------------------------------------------------------------------
        // Default look: a centred command field (max 520 px) in the free space after the sidebar
        Item {
            Layout.fillWidth: true
            Layout.minimumWidth: 220 + (Theme.glass ? 0 : Theme.sp(4))
            Layout.preferredHeight: 44

            Surface {
                id: searchPill
                objectName: "titleSearch"
                kind: "field"
                focused: searchInput.activeFocus
                x: 0
                width: Theme.glass ? parent.width : Math.max(220, Math.min(520, parent.width - Theme.sp(4)))
                height: Theme.glass ? 44 : 30
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.glass ? height / 2 : Theme.radiusCtl

                // a click anywhere on the pill opens the command palette; it sits above the field,
                // which would otherwise take the press for text selection
                MouseArea {
                    objectName: "titleSearchTrigger"
                    anchors.fill: parent
                    z: 10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.focusSearch()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.glass ? Theme.sp(4) : 10
                    anchors.rightMargin: Theme.glass ? Theme.sp(2) : 4
                    spacing: Theme.glass ? 10 : Theme.sp(2)

                    Icon {
                        path: Icons.search
                        size: Theme.glass ? 15 : 14
                        strokeWidth: Theme.glass ? 1.6 : 2
                        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.7) : Theme.textDim
                    }
                    TextField {
                        id: searchInput
                        objectName: "titleSearchField"
                        // a trigger: typing happens in the command palette
                        readOnly: true
                        activeFocusOnPress: false
                        focusPolicy: Qt.NoFocus
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        padding: 0
                        background: null
                        color: Theme.text
                        selectionColor: Theme.glass ? Theme.accentAlpha(0.35) : "#3F3F46"
                        selectedTextColor: Theme.text
                        placeholderText: qsTr("Search torrents, files and commands")
                        placeholderTextColor: Theme.glass ? Theme.textFaint : Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        verticalAlignment: TextInput.AlignVCenter
                        Accessible.name: qsTr("Search and commands")
                        Keys.onEscapePressed: {
                            text = ""
                            focus = false
                        }
                    }
                    // shadcn <Kbd>: muted chip with mono text
                    Rectangle {
                        implicitWidth: hint.implicitWidth + (Theme.glass ? 18 : 10)
                        implicitHeight: Theme.glass ? hint.implicitHeight + 8 : 20
                        radius: Theme.glass ? height / 2 : 4
                        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.08) : Theme.muted

                        Text {
                            id: hint
                            anchors.centerIn: parent
                            text: "Ctrl K"
                            color: Theme.glass ? Qt.rgba(1, 1, 1, 0.72) : Theme.textDim
                            font.family: Theme.glass ? Theme.fontMono : Theme.fontText
                            font.pixelSize: 11
                            font.weight: Theme.glass ? Font.Normal : Font.Medium
                        }
                    }
                }
            }
        }

        // --- Speeds and alternative limits ------------------------------------------------------
        Surface {
            objectName: "titleSpeeds"
            kind: "chrome"
            Layout.preferredHeight: 44
            Layout.preferredWidth: speedRow.implicitWidth + (Theme.glass ? Theme.sp(4) + 6 : Theme.sp(3))
            radius: height / 2

            // the widest plausible speed, so the pill (and the search next to it) does not jitter
            TextMetrics {
                id: speedMetrics
                font.family: Theme.fontMono
                font.pixelSize: Theme.glass ? 13 : Theme.textXs
                text: "↓ " + Format.speed(999.9 * 1024 * 1024)
            }

            RowLayout {
                id: speedRow
                x: Theme.glass ? Theme.sp(4) : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.glass ? 14 : Theme.sp(3)

                Text {
                    objectName: "titleDownRate"
                    Layout.minimumWidth: speedMetrics.advanceWidth
                    horizontalAlignment: Theme.glass ? Text.AlignLeft : Text.AlignRight
                    text: "↓ " + Format.speed(root.downloadRate)
                    color: Theme.glass ? Theme.accent : root.downloadRate > 0 ? Theme.download : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.glass ? 13 : Theme.textXs
                    Accessible.name: qsTr("Download speed %1").arg(Format.speed(root.downloadRate))
                }
                Text {
                    objectName: "titleUpRate"
                    Layout.minimumWidth: speedMetrics.advanceWidth
                    horizontalAlignment: Theme.glass ? Text.AlignLeft : Text.AlignRight
                    text: "↑ " + Format.speed(root.uploadRate)
                    color: Theme.glass ? Theme.upload : root.uploadRate > 0 ? Theme.upload : Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.glass ? 13 : Theme.textXs
                    Accessible.name: qsTr("Upload speed %1").arg(Format.speed(root.uploadRate))
                }
                Item {
                    implicitWidth: Theme.glass ? 32 : 28
                    implicitHeight: implicitWidth

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.glass ? width / 2 : Theme.radiusCtl
                        visible: root.altSpeedEnabled
                        color: Theme.alpha(Theme.warn, 0.16)
                    }
                    IconButton {
                        id: altButton
                        objectName: "titleAltSpeed"
                        anchors.fill: parent
                        iconPath: Icons.turtle
                        iconColor: root.altSpeedEnabled ? Theme.warn : Theme.glass ? Qt.rgba(1, 1, 1, 0.86) : Theme.textDim
                        Accessible.name: qsTr("Alternative speed limits")
                        Accessible.checkable: true
                        Accessible.checked: root.altSpeedEnabled
                        onClicked: SessionFacade.altSpeedEnabled = !root.altSpeedEnabled
                    }
                }
            }
        }

        // --- Window buttons ---------------------------------------------------------------------
        Surface {
            objectName: "titleWindowButtons"
            kind: "chrome"
            Layout.preferredHeight: 44
            Layout.preferredWidth: windowRow.implicitWidth + (Theme.glass ? 12 : 0)
            radius: height / 2

            Row {
                id: windowRow
                anchors.centerIn: parent
                spacing: Theme.glass ? 2 : 0

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
