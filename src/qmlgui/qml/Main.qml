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
        onActivated: palette.visible ? palette.close() : palette.show()
    }
    Shortcut {
        sequence: "Ctrl+O"
        onActivated: window.runCommand("addTorrent")
    }

    CommandPalette {
        id: palette
        actions: [
            { group: qsTr("Actions"), id: "addTorrent", label: qsTr("Add torrent…"), icon: Icons.plus, shortcut: "Ctrl O", keywords: "open file torrent" },
            { group: qsTr("Actions"), id: "addLink", label: qsTr("Add magnet link…"), icon: Icons.link, keywords: "magnet url link" },
            { group: qsTr("Actions"), id: "startAll", label: qsTr("Start all torrents"), icon: Icons.play, keywords: "resume run" },
            { group: qsTr("Actions"), id: "stopAll", label: qsTr("Stop all torrents"), icon: Icons.pause, keywords: "pause" },
            { group: qsTr("Actions"), id: "altSpeed", icon: Icons.turtle, keywords: "turtle speed limit alternative",
              label: SessionFacade.altSpeedEnabled ? qsTr("Turn off alternative speed limits") : qsTr("Turn on alternative speed limits") },
            { group: qsTr("Actions"), id: "refreshRss", label: qsTr("Refresh RSS feeds"), icon: Icons.refresh, keywords: "rss feeds update" },
            { group: qsTr("Actions"), id: "theme", icon: Icons.uiPanel, keywords: "theme look appearance glass default",
              label: Theme.glass ? qsTr("Switch to the default look") : qsTr("Switch to Liquid Glass") },
            { group: qsTr("Go to"), id: "page", arg: 0, label: qsTr("Transfers"), icon: Icons.download, shortcut: "Ctrl 1" },
            { group: qsTr("Go to"), id: "status", arg: "downloading", label: qsTr("Transfers: downloading"), icon: Icons.down },
            { group: qsTr("Go to"), id: "status", arg: "seeding", label: qsTr("Transfers: seeding"), icon: Icons.up },
            { group: qsTr("Go to"), id: "status", arg: "completed", label: qsTr("Transfers: completed"), icon: Icons.check },
            { group: qsTr("Go to"), id: "page", arg: 1, label: qsTr("Tracker search"), icon: Icons.search, shortcut: "Ctrl 2" },
            { group: qsTr("Go to"), id: "page", arg: 2, label: qsTr("RSS feeds"), icon: Icons.rss, shortcut: "Ctrl 3" },
            { group: qsTr("Go to"), id: "page", arg: 3, label: qsTr("Media library"), icon: Icons.media, shortcut: "Ctrl 4" },
            { group: qsTr("Go to"), id: "settings", arg: "interface", label: qsTr("Settings"), icon: Icons.settings, shortcut: "Ctrl ,",
              keywords: "preferences options interface theme" },
            { group: qsTr("Go to"), id: "settings", arg: "downloads", label: qsTr("Settings: downloads"), icon: Icons.settings, keywords: "folder save path" },
            { group: qsTr("Go to"), id: "settings", arg: "speed", label: qsTr("Settings: speed"), icon: Icons.settings, keywords: "limit schedule" },
            { group: qsTr("Go to"), id: "settings", arg: "connection", label: qsTr("Settings: connection"), icon: Icons.settings, keywords: "port proxy upnp" },
            { group: qsTr("Go to"), id: "settings", arg: "bittorrent", label: qsTr("Settings: BitTorrent"), icon: Icons.settings, keywords: "dht queue ratio seeding" },
            { group: qsTr("Go to"), id: "settings", arg: "advanced", label: qsTr("Settings: advanced"), icon: Icons.settings, keywords: "libtorrent disk network" }
        ]
        onTriggered: (id, arg) => window.runCommand(id, arg)
    }

    // Carries out a command palette entry (also Ctrl+O)
    function runCommand(id, arg) {
        switch (id) {
        case "torrent":
            currentPage = 0
            TransfersState.status = "all"
            TransfersState.focusId = arg
            break
        case "addTorrent":
            currentPage = 0
            transfersPage.openAddFile()
            break
        case "addLink":
            currentPage = 0
            transfersPage.openAddLink()
            break
        case "startAll":
            TorrentListModel.start(TorrentListModel.allIds())
            break
        case "stopAll":
            TorrentListModel.stop(TorrentListModel.allIds())
            break
        case "altSpeed":
            SessionFacade.altSpeedEnabled = !SessionFacade.altSpeedEnabled
            break
        case "refreshRss":
            RssManager.refresh("")
            break
        case "theme":
            UiSettings.style = Theme.glass ? "default" : "glass"
            break
        case "page":
            currentPage = arg
            break
        case "status":
            TransfersState.status = arg
            currentPage = 0
            break
        case "settings":
            settingsPage.section = arg
            currentPage = 4
            break
        case "searchTrackers":
            currentPage = 1
            searchPage.searchFor(arg)
            break
        }
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
            onCommandsRequested: palette.show()
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

                TransfersPage { id: transfersPage }
                SearchPage { id: searchPage }
                RssPage {}
                MediaPage {}
                SettingsPage { id: settingsPage }
            }
        }
    }
}
