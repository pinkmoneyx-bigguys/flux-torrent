import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The glass navigation column: the four sections at the top and Settings at the bottom. It only shows
// `currentIndex` and asks for a change with navigate(); the window owns the current page.
// Indices: 0 Transfers, 1 Tracker search, 2 RSS feeds, 3 Media library, 4 Settings.
GlassPanel {
    id: root

    property int currentIndex: 0
    signal navigate(int index)

    implicitWidth: 236
    radius: Theme.radiusPanel

    Accessible.role: Accessible.PageTabList
    Accessible.name: qsTr("Sections")

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.gap
        spacing: Theme.sp(1)

        NavItem {
            objectName: "nav_transfers"
            page: 0
            text: qsTr("Transfers")
            iconPath: Icons.download
            meta: SessionFacade.torrentCount > 0 ? Number(SessionFacade.torrentCount).toLocaleString(Qt.locale(), "f", 0) : ""
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

    // One 38 px row. The highlight of the current row changes instantly (also from Ctrl+N); only the
    // pointer hover fades.
    component NavItem: AbstractButton {
        id: item

        property int page
        property string iconPath
        property string meta
        readonly property bool current: root.currentIndex === page
        readonly property color _ink: current ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.84)

        Layout.fillWidth: true
        implicitHeight: 38
        leftPadding: Theme.sp(3)
        rightPadding: Theme.sp(3)
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true

        onClicked: root.navigate(page)

        scale: pressed && !Theme.reducedMotion && !_kbd ? 0.97 : 1.0
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
            // drop shadow of the raised current row: 0 10px 24px -12px rgba(0,0,0,.7)
            GlowHalo {
                anchors.fill: parent
                visible: item.current
                color: Qt.rgba(0, 0, 0, 0.7)
                radius: 14
                spread: 6
                offsetY: 8
            }
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.08)
                opacity: item.hovered && !item.current ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durFast }
                }
            }
            Rectangle {
                id: selected
                anchors.fill: parent
                radius: 14
                visible: item.current
                color: Qt.rgba(1, 1, 1, 0.12)
            }
            // inset top highlight, starting where the rounded corners end
            Rectangle {
                visible: item.current
                x: selected.radius - Math.sqrt(Math.max(0, 2 * selected.radius - 1))
                width: parent.width - 2 * x
                height: 1
                color: Qt.rgba(1, 1, 1, 0.14)
            }
            Rectangle {
                visible: item.visualFocus
                anchors.fill: parent
                anchors.margins: -2
                radius: 16
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
            }
        }

        contentItem: RowLayout {
            spacing: 10

            Icon {
                path: item.iconPath
                color: item._ink
                size: 16
                strokeWidth: 1.5
            }
            Text {
                objectName: item.objectName + "_label"
                Layout.fillWidth: true
                text: item.text
                color: item._ink
                font.family: Theme.fontText
                font.pixelSize: 13
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                visible: item.meta !== ""
                text: item.meta
                color: Qt.rgba(1, 1, 1, 0.6)
                font.family: Theme.fontMono
                font.pixelSize: 12
            }
        }
    }
}
