import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The top of the frameless window: the logo (a click folds the sidebar), the main actions and the window
// buttons. Default look: one flat strip on the window chrome with Windows-style caption buttons. Glass
// look: separate frosted pills. (Search and commands: Ctrl+K opens the command palette.)
// Main.qml hands the window buttons and `interactiveItems` to QWindowKit; the rest drags the window.
Item {
    id: root

    // Plain property bound to the session, so tests can drive it
    property bool altSpeedEnabled: SessionFacade.altSpeedEnabled
    // Default look: the logo block is as wide as the sidebar under it
    property real logoWidth: 236
    property bool sidebarCollapsed: false
    // the folded sidebar's width (default look), to centre the logo over it
    property real railWidth: 48

    readonly property alias altSpeedButton: altButton
    readonly property alias logoButton: logoBtn
    readonly property alias minimizeButton: minBtn
    readonly property alias maximizeButton: maxBtn
    readonly property alias closeButton: closeBtn
    // Clickable parts that must not drag the window; the last three are also the agent's system buttons
    readonly property list<Item> interactiveItems: [logoBtn, addBtn, linkBtn, createBtn, startBtn, stopBtn,
                                                    altButton, minBtn, maxBtn, closeBtn]

    signal sidebarToggleRequested()
    // "addTorrent", "addLink", "createTorrent", "startAll", "stopAll", "altSpeed" (Main.runCommand)
    signal actionRequested(string id)
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
            // a fixed spot in each state (never the animating block width, which would restart the slide
            // every frame): centred over the folded rail, or at the usual inset
            x: Theme.glass ? (root.sidebarCollapsed ? 7 : Theme.sp(2)) : (root.sidebarCollapsed ? (root.railWidth - 24) / 2 : Theme.sp(4))
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
}
