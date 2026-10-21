import QtQuick
import QtQuick.Layouts
import Flux

// The menu of the icon in the notification area, in Flux's look rather than Windows' light one: a window of
// its own at the mouse pointer (the main window may be hidden), the speeds on top. It takes the focus when it
// opens and goes as soon as it loses it, like the system's menus; Esc, the arrows and Enter work too.
Window {
    id: menu
    objectName: "trayMenu"

    // the main window: whether it shows decides "Open" or "Hide"
    property var target: null
    signal triggered(string id)

    // a window of its own, never one of the main window's: that one may be hidden or minimized
    transientParent: null
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: Theme.popover
    width: 288
    height: body.implicitHeight + 2 * pad
    title: "Flux Torrent"

    readonly property int pad: 4
    readonly property bool targetShown: !!target && target.visible && target.visibility !== Window.Minimized
    readonly property var items: [
        { id: "toggle", icon: Icons.app, label: targetShown ? qsTr("Hide Flux") : qsTr("Open Flux") },
        { separator: true },
        { id: "addTorrent", icon: Icons.filePlus, label: qsTr("Add a torrent file…") },
        { id: "addLink", icon: Icons.magnet, label: qsTr("Add a magnet link…") },
        { separator: true },
        { id: "startAll", icon: Icons.play, label: qsTr("Start all torrents") },
        { id: "stopAll", icon: Icons.pause, label: qsTr("Stop all torrents") },
        { id: "altSpeed", icon: Icons.turtle, label: qsTr("Alternative speed limits"), checked: SessionFacade.altSpeedEnabled },
        { separator: true },
        { id: "quit", icon: Icons.x, label: qsTr("Exit Flux") }
    ]
    // the row the keyboard is on (-1: none)
    property int current: -1

    function popup() {
        const at = Tray.menuPosition(width, height)
        x = at.x
        y = at.y
        current = -1
        show()
        Tray.decorate(menu, Theme.border)
        Tray.activate(menu)
    }
    function choose(index) {
        const item = items[index]
        if (!item || item.separator)
            return
        close()
        triggered(item.id)
    }
    function step(delta) {
        let i = current
        for (let n = 0; n < items.length; ++n) {
            i = (i + delta + items.length) % items.length
            if (!items[i].separator) {
                current = i
                return
            }
        }
    }

    // a click anywhere else (or another window) takes the focus away
    onActiveChanged: {
        if (!active && visible)
            close()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.close()
        Keys.onUpPressed: menu.step(-1)
        Keys.onDownPressed: menu.step(1)
        Keys.onReturnPressed: menu.choose(menu.current)
        Keys.onEnterPressed: menu.choose(menu.current)

        ColumnLayout {
            id: body
            x: menu.pad
            y: menu.pad
            width: parent.width - 2 * menu.pad
            spacing: 0

            // who, and what it is doing right now
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 8
                Layout.bottomMargin: 6
                spacing: 10

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 7
                    color: Theme.primary
                    Icon {
                        anchors.centerIn: parent
                        path: Icons.logo
                        size: 16
                        strokeWidth: 2.2
                        color: Theme.primaryText
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "Flux Torrent"
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        font.weight: Font.DemiBold
                    }
                    Row {
                        spacing: 10
                        Repeater {
                            model: [
                                { icon: Icons.down, color: Theme.download, rate: SessionFacade.downloadRate },
                                { icon: Icons.up, color: Theme.upload, rate: SessionFacade.uploadRate }
                            ]
                            Row {
                                required property var modelData
                                spacing: 3
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    path: modelData.icon
                                    size: 12
                                    strokeWidth: 2
                                    color: modelData.color
                                }
                                Text {
                                    text: Format.speed(modelData.rate)
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.textXs
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: menu.items
                delegate: Loader {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    sourceComponent: modelData.separator ? separator : entry

                    Component {
                        id: separator
                        Item {
                            implicitHeight: 9
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: -menu.pad
                                width: parent.width + 2 * menu.pad
                                height: 1
                                color: Theme.border
                            }
                        }
                    }
                    Component {
                        id: entry
                        Rectangle {
                            objectName: "trayItem_" + row.modelData.id
                            implicitHeight: 32
                            radius: Theme.radiusCtl - 2
                            color: menu.current === row.index ? Theme.hover : Theme.alpha(Theme.hover, 0)
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                            Accessible.role: row.modelData.checked !== undefined ? Accessible.CheckBox : Accessible.MenuItem
                            Accessible.name: row.modelData.label
                            Accessible.checkable: row.modelData.checked !== undefined
                            Accessible.checked: row.modelData.checked === true
                            Accessible.onPressAction: menu.choose(row.index)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: Theme.sp(2)
                                Icon {
                                    path: row.modelData.icon
                                    size: 16
                                    strokeWidth: 1.75
                                    color: row.modelData.checked ? Theme.text : Theme.textDim
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    elide: Text.ElideRight
                                }
                                Icon {
                                    visible: row.modelData.checked === true
                                    path: Icons.check
                                    size: 14
                                    strokeWidth: 2
                                    color: Theme.text
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: menu.current = row.index
                                onExited: {
                                    if (menu.current === row.index)
                                        menu.current = -1
                                }
                                onClicked: menu.choose(row.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
