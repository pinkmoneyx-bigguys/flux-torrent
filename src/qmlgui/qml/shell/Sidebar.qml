import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The navigation column: the four sections at the top and Settings at the bottom. It only shows
// `currentIndex` and asks for a change with navigate(); the window owns the current page.
// Default look: flat on the window chrome, shadcn sidebar menu rows. Glass look: a frosted pane.
// Indices: 0 Transfers, 1 Tracker search, 2 RSS feeds, 3 Media library, 4 Settings.
Surface {
    id: root

    property int currentIndex: 0
    signal navigate(int index)

    kind: "chrome"
    implicitWidth: 236
    radius: Theme.radiusPanel

    // Padding around the rows: glass 12, default 8 (shadcn p-2)
    readonly property int padding: Theme.glass ? Theme.gap : Theme.sp(2)

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Sections")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Theme.glass ? Theme.sp(1) : 2

        // shadcn SidebarGroupLabel
        Text {
            visible: !Theme.glass
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            leftPadding: Theme.sp(2)
            text: qsTr("Library")
            color: Theme.alpha(Theme.text, 0.7)
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
            Accessible.ignored: true
        }

        NavItem {
            objectName: "nav_transfers"
            page: 0
            text: qsTr("Transfers")
            iconPath: Icons.download
            meta: SessionFacade.torrentCount > 0 ? Number(SessionFacade.torrentCount).toLocaleString(Qt.locale(), "f", 0) : ""
            hasSub: true
        }

        // Status filters of the Transfers page (shadcn SidebarMenuSub: indented, a border line on the left)
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            implicitHeight: subColumn.implicitHeight + 4

            Rectangle {
                width: 1
                height: parent.height
                color: Theme.border
            }
            ColumnLayout {
                id: subColumn
                x: 10
                y: 2
                width: parent.width - 10
                spacing: 2

                Repeater {
                    model: TransfersState.filters

                    StatusItem {
                        required property var modelData
                        objectName: "nav_status_" + modelData.key
                        status: modelData.key
                        text: modelData.label
                        // "Errors" only shows up when there is something to see
                        visible: modelData.key !== "errored" || count > 0 || current
                    }
                }
            }
        }
        NavItem {
            objectName: "nav_search"
            page: 1
            text: qsTr("Tracker search")
            iconPath: Icons.search
        }
        NavItem {
            objectName: "nav_rss"
            page: 2
            text: qsTr("RSS feeds")
            iconPath: Icons.rss
        }
        NavItem {
            objectName: "nav_media"
            page: 3
            text: qsTr("Media library")
            iconPath: Icons.media
        }

        Item {
            Layout.fillHeight: true
        }

        NavItem {
            objectName: "nav_settings"
            page: 4
            text: qsTr("Settings")
            iconPath: Icons.settings
        }
    }

    // A 28 px status filter row under Transfers: picks the filter and shows the Transfers page
    component StatusItem: AbstractButton {
        id: sub

        property string status
        readonly property int count: TorrentListModel.counts[status] ?? 0
        readonly property bool current: root.currentIndex === 0 && TransfersState.status === status

        Layout.fillWidth: true
        implicitHeight: 28
        leftPadding: Theme.sp(2)
        rightPadding: Theme.sp(2)
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        onClicked: {
            TransfersState.status = status
            root.navigate(0)
        }

        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.checked: current
        Accessible.onPressAction: sub.clicked()

        background: Rectangle {
            radius: Theme.glass ? 10 : Theme.radiusCtl - 2
            color: sub.current ? Theme.selected : sub.hovered ? Theme.hover : "transparent"
            border.width: sub.visualFocus ? 2 : 0
            border.color: Theme.glass ? Theme.accent : Theme.ring
        }
        contentItem: RowLayout {
            spacing: Theme.sp(2)
            Text {
                Layout.fillWidth: true
                text: sub.text
                color: sub.current ? Theme.text : Theme.alpha(Theme.text, 0.7)
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: sub.current ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                visible: sub.count > 0
                text: Number(sub.count).toLocaleString(Qt.locale(), "f", 0)
                color: sub.status === "errored" ? Theme.error : Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }

    // One row: 38 px glass, 32 px default (shadcn SidebarMenuButton h-8). The highlight of the current
    // row changes instantly (also from Ctrl+N); only the pointer hover fades.
    component NavItem: AbstractButton {
        id: item

        property int page
        property string iconPath
        property string meta
        // Has status filters under it: when current, the active filter carries the highlight instead
        property bool hasSub: false
        readonly property bool current: root.currentIndex === page
        readonly property color _ink: Theme.glass ? (current ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.84))
                                                  : (current ? Theme.text : Theme.alpha(Theme.text, 0.82))
        readonly property real _radius: Theme.glass ? 14 : Theme.radiusRow

        Layout.fillWidth: true
        implicitHeight: Theme.glass ? 38 : 32
        leftPadding: Theme.glass ? Theme.sp(3) : Theme.sp(2)
        rightPadding: Theme.glass ? Theme.sp(3) : Theme.sp(2)
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        onClicked: root.navigate(page)

        scale: Theme.glass && pressed && !Theme.reducedMotion && !_kbd ? 0.97 : 1.0
        Behavior on scale {
            enabled: !Theme.reducedMotion
            NumberAnimation {
                duration: Theme.durPress
                easing.type: Theme.easing.type
                easing.bezierCurve: Theme.easing.bezierCurve
            }
        }

        // Space activates without animation: keyboard actions never animate
        property bool _kbd: false
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space && !event.isAutoRepeat)
                item._kbd = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Space && !event.isAutoRepeat)
                Qt.callLater(() => item._kbd = false)
        }
        onActiveFocusChanged: if (!activeFocus) _kbd = false

        Accessible.role: Accessible.PageTab
        Accessible.name: text
        Accessible.selected: current
        Accessible.onPressAction: item.clicked()

        background: Item {
            // glass: drop shadow of the raised current row: 0 10px 24px -12px rgba(0,0,0,.7)
            GlowHalo {
                anchors.fill: parent
                visible: Theme.glass && item.current && !item.hasSub
                color: Qt.rgba(0, 0, 0, 0.7)
                radius: item._radius
                spread: 24
                offsetY: 10
                shrink: 12
            }
            Rectangle {
                anchors.fill: parent
                radius: item._radius
                color: Theme.hover
                opacity: item.hovered && !item.current ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }
            Rectangle {
                id: selected
                anchors.fill: parent
                radius: item._radius
                visible: item.current && !item.hasSub
                color: Theme.selected
            }
            // glass: inset top highlight, starting where the rounded corners end
            Rectangle {
                visible: Theme.glass && item.current && !item.hasSub
                x: selected.radius - Math.sqrt(Math.max(0, 2 * selected.radius - 1))
                width: parent.width - 2 * x
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }
            Rectangle {
                visible: item.visualFocus
                anchors.fill: parent
                anchors.margins: Theme.glass ? -2 : 0
                radius: Theme.glass ? 16 : item._radius
                color: "transparent"
                border.width: 2
                border.color: Theme.glass ? Theme.accent : Theme.ring
            }
        }

        contentItem: RowLayout {
            spacing: Theme.glass ? 10 : Theme.sp(2)

            Icon {
                path: item.iconPath
                color: item._ink
                size: 16
                strokeWidth: Theme.glass ? 1.5 : 1.75
            }
            Text {
                objectName: item.objectName + "_label"
                Layout.fillWidth: true
                text: item.text
                color: item._ink
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: !Theme.glass && item.current ? Font.Medium : Font.Normal
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                visible: item.meta !== ""
                text: item.meta
                color: Theme.glass ? Qt.rgba(1, 1, 1, 0.6) : Theme.textDim
                font.family: Theme.glass ? Theme.fontMono : Theme.fontText
                font.pixelSize: Theme.textXs
                font.weight: Theme.glass ? Font.Normal : Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }
}
