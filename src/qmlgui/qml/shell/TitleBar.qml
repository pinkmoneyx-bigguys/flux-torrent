import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The top of the frameless window: the logo (a click folds the sidebar), the search pill centred on the
// window (it opens the command palette), the main actions, and the window buttons. Default look: one flat
// strip on the window chrome with Windows-style caption buttons. Glass look: separate frosted pills.
// Main.qml hands the window buttons and `interactiveItems` to QWindowKit; the rest drags the window.
Item {
    id: root

    // Plain property bound to the session, so tests can drive it
    property bool altSpeedEnabled: SessionFacade.altSpeedEnabled
    // Default look: the logo block is as wide as the sidebar under it
    property real logoWidth: 236
    property bool sidebarCollapsed: false

    readonly property alias searchField: searchInput
    readonly property alias altSpeedButton: altButton
    readonly property alias logoButton: logoBtn
    readonly property alias minimizeButton: minBtn
    readonly property alias maximizeButton: maxBtn
    readonly property alias closeButton: closeBtn
    // Clickable parts that must not drag the window; the last three are also the agent's system buttons
    readonly property list<Item> interactiveItems: [logoBtn, searchPill, addBtn, linkBtn, createBtn, startBtn, stopBtn,
                                                    altButton, minBtn, maxBtn, closeBtn]

    // The search pill opens the command palette (Main shows it)
    signal commandsRequested()
    signal sidebarToggleRequested()
    // "addTorrent", "addLink", "createTorrent", "startAll", "stopAll", "altSpeed" (Main.runCommand)
    signal actionRequested(string id)
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
                           : Qt.rgba(1, 1, 1, wb.pressed ? (Theme.glass ? 0.12 : 0.06) : wb.hovered ? 0.08 : 0)
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

    // A toolbar action: an icon with its name in a tooltip under it. `checked` paints it amber (on).
    component ToolButton: AbstractButton {
        id: tb

        property string iconPath
        property color onColor: Theme.warn

        implicitWidth: Theme.glass ? 34 : 32
        implicitHeight: Theme.glass ? 32 : 30
        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: tb.clicked()

        background: Rectangle {
            radius: Theme.glass ? height / 2 : Theme.radiusCtl
            color: tb.checked ? Theme.alpha(tb.onColor, 0.16)
                              : Qt.rgba(1, 1, 1, tb.pressed ? 0.12 : tb.hovered ? 0.08 : 0)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                path: tb.iconPath
                size: 16
                strokeWidth: Theme.glass ? 1.6 : 1.75
                color: tb.checked ? tb.onColor : tb.hovered ? Theme.text : Theme.glass ? Qt.rgba(1, 1, 1, 0.86) : Theme.textDim
                Behavior on color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }
            }
        }

        UiTooltip {
            text: tb.text
            placement: "bottom"
            shown: tb.hovered
        }
    }

    component ToolSeparator: Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 1
        implicitHeight: 18
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.border
    }

    // --- Logo (left) --------------------------------------------------------------------------
    Surface {
        id: logoBlock
        objectName: "titleLogo"
        kind: "chrome"
        x: 0
        width: Theme.glass ? (root.sidebarCollapsed ? 44 : logoRow.implicitWidth + Theme.sp(2) + Theme.sp(4)) : root.logoWidth
        height: 44
        radius: height / 2
        Behavior on width {
            enabled: !Theme.reducedMotion && Theme.glass
            NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
        }
        clip: true

        RowLayout {
            id: logoRow
            x: Theme.glass ? (root.sidebarCollapsed ? 7 : Theme.sp(2)) : (root.sidebarCollapsed ? (root.logoWidth - 24) / 2 : Theme.sp(4))
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.glass ? 10 : Theme.sp(2)
            Behavior on x {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
            }

            // the mark is the sidebar's fold button
            AbstractButton {
                id: logoBtn
                objectName: "titleLogoButton"
                implicitWidth: Theme.glass ? 30 : 24
                implicitHeight: implicitWidth
                focusPolicy: Qt.NoFocus
                hoverEnabled: true
                text: root.sidebarCollapsed ? qsTr("Expand the sidebar") : qsTr("Collapse the sidebar")
                onClicked: root.sidebarToggleRequested()

                Accessible.role: Accessible.Button
                Accessible.name: text

                background: Item {
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
                        scale: logoBtn.pressed ? 0.92 : logoBtn.hovered ? 1.06 : 1
                        Behavior on scale {
                            enabled: !Theme.reducedMotion
                            NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic }
                        }
                    }
                }
                contentItem: Item {
                    Icon {
                        anchors.centerIn: parent
                        path: Icons.logo
                        size: Theme.glass ? 16 : 14
                        strokeWidth: Theme.glass ? 2.6 : 2.4
                        color: Theme.primaryText
                        // the mark turns on its side while the sidebar is folded
                        rotation: root.sidebarCollapsed ? -90 : 0
                        Behavior on rotation {
                            enabled: !Theme.reducedMotion
                            NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
                        }
                    }
                }

                UiTooltip {
                    text: logoBtn.text
                    placement: "bottom"
                    shown: logoBtn.hovered
                }
            }
            Text {
                text: "Flux"
                opacity: root.sidebarCollapsed ? 0 : 1
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
                color: Theme.text
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.glass ? 13 : Theme.textBase
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.glass ? -0.26 : -0.2
                Accessible.ignored: true
            }
        }
    }

    // --- Actions and window buttons (right) ----------------------------------------------------
    RowLayout {
        id: rightBlock
        anchors.right: parent.right
        height: parent.height
        spacing: Theme.glass ? Theme.gap : Theme.sp(1)

        Surface {
            objectName: "titleActions"
            kind: "chrome"
            Layout.preferredHeight: 44
            Layout.preferredWidth: actionRow.implicitWidth + (Theme.glass ? 12 : 0)
            radius: height / 2

            RowLayout {
                id: actionRow
                anchors.centerIn: parent
                spacing: 2

                ToolButton {
                    id: addBtn
                    objectName: "titleAddTorrent"
                    text: qsTr("Add a torrent file")
                    iconPath: Icons.plus
                    onClicked: root.actionRequested("addTorrent")
                }
                ToolButton {
                    id: linkBtn
                    objectName: "titleAddLink"
                    text: qsTr("Add a magnet link")
                    iconPath: Icons.link
                    onClicked: root.actionRequested("addLink")
                }
                ToolButton {
                    id: createBtn
                    objectName: "titleCreateTorrent"
                    text: qsTr("Create a torrent")
                    iconPath: Icons.filePlus
                    onClicked: root.actionRequested("createTorrent")
                }
                ToolSeparator {}
                ToolButton {
                    id: startBtn
                    objectName: "titleStartAll"
                    text: qsTr("Start all")
                    iconPath: Icons.play
                    onClicked: root.actionRequested("startAll")
                }
                ToolButton {
                    id: stopBtn
                    objectName: "titleStopAll"
                    text: qsTr("Stop all")
                    iconPath: Icons.pause
                    onClicked: root.actionRequested("stopAll")
                }
                ToolButton {
                    id: altButton
                    objectName: "titleAltSpeed"
                    text: qsTr("Alternative speed limits")
                    iconPath: Icons.turtle
                    checkable: false
                    checked: root.altSpeedEnabled
                    Accessible.checkable: true
                    Accessible.checked: root.altSpeedEnabled
                    onClicked: root.actionRequested("altSpeed")
                }
            }
        }

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

    // --- Search (centred on the window) --------------------------------------------------------
    // As wide as 420 px allows between the logo and the actions; centred on the window when it fits
    Surface {
        id: searchPill
        objectName: "titleSearch"
        kind: "field"
        focused: searchInput.activeFocus

        readonly property real leftLimit: logoBlock.width + Theme.sp(3)
        readonly property real rightLimit: rightBlock.x - Theme.sp(3)
        readonly property real room: rightLimit - leftLimit
        visible: room >= 160
        width: Math.max(160, Math.min(420, room))
        height: Theme.glass ? 44 : 30
        x: Math.max(leftLimit, Math.min(rightLimit - width, (root.width - width) / 2))
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
