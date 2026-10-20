import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QWindowKit
import Flux

// The Flux window: frameless (QWindowKit keeps native snap, shadow and rounded corners), with the title
// bar, sidebar and page stack. Default look: title strip and sidebar flat on the window chrome, pages on
// an inset card 8 px from the right and bottom edges. Glass look: everything 12 px from the edges and
// from each other over the coloured backdrop.
// No Mica: the opaque in-app backdrop would cover it, and without it Windows 10 and 11 look the same.
ApplicationWindow {
    id: window

    // 0 Transfers, 1 Tracker search, 2 RSS feeds, 3 Media library, 4 Settings
    property int currentPage: 0
    // The title-bar items registered with the agent as hit-test visible (clickable, not a drag area)
    property var titleBarHitTestItems: []
    readonly property alias windowAgent: agent
    readonly property alias titleBarArea: titleBarArea

    width: 1440
    height: 920
    minimumWidth: 1100
    minimumHeight: 720
    // shown by Component.onCompleted once the agent has made the window frameless
    visible: false
    color: Theme.bg
    title: "Flux"

    WindowAgent {
        id: agent
    }

    Component.onCompleted: {
        Theme.glassSource = backdrop

        agent.setup(window)
        // dark system surfaces (snap layout flyout, border); Windows 11 22H2+
        if (SystemPrefs.windowsBuild >= 22621)
            agent.setWindowAttribute("dark-mode", true)

        agent.setTitleBar(titleBarArea)
        agent.setSystemButton(WindowAgent.Minimize, titleBar.minimizeButton)
        agent.setSystemButton(WindowAgent.Maximize, titleBar.maximizeButton)
        agent.setSystemButton(WindowAgent.Close, titleBar.closeButton)
        const registered = []
        for (const item of titleBar.interactiveItems) {
            agent.setHitTestVisible(item, true)
            registered.push(item)
        }
        titleBarHitTestItems = registered

        visible = true
    }

    // Page switching from the keyboard is instant, like every keyboard action
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: window.currentPage = 0
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: window.currentPage = 1
    }
    Shortcut {
        sequence: "Ctrl+3"
        onActivated: window.currentPage = 2
    }
    Shortcut {
        sequence: "Ctrl+4"
        onActivated: window.currentPage = 3
    }
    Shortcut {
        sequence: "Ctrl+,"
        onActivated: window.currentPage = 4
    }
    Shortcut {
        sequence: "Ctrl+K"
        onActivated: titleBar.focusSearch()
    }

    GlassBackground {
        id: backdrop
        visible: Theme.glass
    }

    // The drag area: the full window width from the top edge down to the bottom of the pills
    Item {
        id: titleBarArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: (Theme.glass ? Theme.gap : 0) + titleBar.implicitHeight

        TitleBar {
            id: titleBar
            objectName: "titleBar"
            anchors.fill: parent
            anchors.leftMargin: Theme.glass ? Theme.gap : 0
            anchors.rightMargin: Theme.glass ? Theme.gap : 0
            anchors.topMargin: Theme.glass ? Theme.gap : 0
            logoWidth: sidebar.width
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleBarArea.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.glass ? Theme.gap : 0
        anchors.topMargin: Theme.glass ? Theme.gap : 0
        anchors.rightMargin: Theme.glass ? Theme.gap : Theme.sp(2)
        anchors.bottomMargin: Theme.glass ? Theme.gap : Theme.sp(2)
        spacing: Theme.glass ? Theme.gap : 0

        Sidebar {
            id: sidebar
            objectName: "sidebar"
            Layout.preferredWidth: 236
            Layout.fillHeight: true
            currentIndex: window.currentPage
            onNavigate: index => window.currentPage = index
        }

        // shadcn SidebarInset; nothing in the glass look, where each page brings its own panes
        Surface {
            id: pageArea
            objectName: "pageArea"
            kind: "inset"
            Layout.fillWidth: true
            Layout.fillHeight: true

            StackLayout {
                id: pages
                objectName: "pages"
                anchors.fill: parent
                currentIndex: window.currentPage

                TransfersPage {}
                SearchPage {}
                RssPage {}
                MediaPage {}
                SettingsPage {}
            }
        }
    }
}
