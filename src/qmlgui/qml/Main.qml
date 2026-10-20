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
    // The sidebar folded to a rail of icons (the logo or Ctrl+B); remembered in the profile
    property bool sidebarCollapsed: UiSettings.layoutValue("sidebarCollapsed", false)
    function toggleSidebar() {
        sidebarCollapsed = !sidebarCollapsed
        UiSettings.setLayoutValue("sidebarCollapsed", sidebarCollapsed)
    }
    // The title-bar items registered with the agent as hit-test visible (clickable, not a drag area)
    property var titleBarHitTestItems: []
    readonly property alias windowAgent: agent
    readonly property alias titleBarArea: titleBarArea
    readonly property alias playerView: playerView

    // Well under the screen, never more than 1200 × 760: a window beside others, not over them
    width: Math.round(Math.max(minimumWidth, Math.min(1200, Screen.width * 0.62)))
    height: Math.round(Math.max(minimumHeight, Math.min(760, (Screen.height - 48) * 0.68)))
    minimumWidth: 960
    minimumHeight: 620
    // shown by Component.onCompleted once the agent has made the window frameless
    visible: false
    color: Theme.bg
    title: "Flux Torrent"

    WindowAgent {
        id: agent
    }

    Component.onCompleted: {
        Theme.glassSource = backdrop

        agent.setup(window)
        // centred on the screen it opens on (48 px: room for the taskbar)
        x = Screen.virtualX + Math.round((Screen.width - width) / 2)
        y = Screen.virtualY + Math.max(0, Math.round((Screen.height - 48 - height) / 2))
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
        // a quiet look for a newer release (when the user lets it)
        Qt.callLater(Updater.checkIfDue)
        // the last update could not put its files in place: say so, the details are in About
        if (Updater.installState === "failed") {
            toastPurpose = "update"
            windowToast.show(qsTr("The update was not installed"), false, qsTr("Details"))
        }
    }

    // Page switching from the keyboard
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
        sequence: "Ctrl+B"
        onActivated: window.toggleSidebar()
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
            { group: qsTr("Actions"), id: "createTorrent", label: qsTr("Create a torrent…"), icon: Icons.filePlus, keywords: "new make share seed" },
            { group: qsTr("Actions"), id: "toggleSidebar", label: window.sidebarCollapsed ? qsTr("Expand the sidebar") : qsTr("Collapse the sidebar"),
              icon: Icons.uiPanel, shortcut: "Ctrl B", keywords: "menu navigation compact" },
            { group: qsTr("Actions"), id: "startAll", label: qsTr("Start all torrents"), icon: Icons.play, keywords: "resume run" },
            { group: qsTr("Actions"), id: "stopAll", label: qsTr("Stop all torrents"), icon: Icons.pause, keywords: "pause" },
            { group: qsTr("Actions"), id: "altSpeed", icon: Icons.turtle, keywords: "turtle speed limit alternative",
              label: SessionFacade.altSpeedEnabled ? qsTr("Turn off alternative speed limits") : qsTr("Turn on alternative speed limits") },
            { group: qsTr("Actions"), id: "refreshRss", label: qsTr("Refresh RSS feeds"), icon: Icons.refresh, keywords: "rss feeds update" },
            { group: qsTr("Go to"), id: "page", arg: 0, label: qsTr("Transfers"), icon: Icons.download, shortcut: "Ctrl 1" },
            { group: qsTr("Go to"), id: "status", arg: "downloading", label: qsTr("Transfers: downloading"), icon: Icons.down },
            { group: qsTr("Go to"), id: "status", arg: "seeding", label: qsTr("Transfers: seeding"), icon: Icons.up },
            { group: qsTr("Go to"), id: "status", arg: "completed", label: qsTr("Transfers: completed"), icon: Icons.check },
            { group: qsTr("Go to"), id: "page", arg: 1, label: qsTr("Tracker search"), icon: Icons.search, shortcut: "Ctrl 2" },
            { group: qsTr("Go to"), id: "page", arg: 2, label: qsTr("RSS feeds"), icon: Icons.rss, shortcut: "Ctrl 3" },
            { group: qsTr("Go to"), id: "page", arg: 3, label: qsTr("Media library"), icon: Icons.media, shortcut: "Ctrl 4" },
            { group: qsTr("Go to"), id: "settings", arg: "downloads", label: qsTr("Settings"), icon: Icons.settings, shortcut: "Ctrl ,",
              keywords: "preferences options" },
            { group: qsTr("Go to"), id: "settings", arg: "about", label: qsTr("About Flux"), icon: Icons.info, keywords: "version update github" },
            { group: qsTr("Actions"), id: "checkUpdates", label: qsTr("Check for updates"), icon: Icons.refresh, keywords: "version release new" },
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
        case "createTorrent":
            createTorrentDialog.open()
            break
        case "toggleSidebar":
            toggleSidebar()
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
        case "checkUpdates":
            settingsPage.section = "about"
            currentPage = 4
            Updater.check()
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
            onSidebarToggleRequested: window.toggleSidebar()
            onActionRequested: id => window.runCommand(id)
            sidebarCollapsed: window.sidebarCollapsed
            railWidth: sidebar.railWidth
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
            Layout.preferredWidth: window.sidebarCollapsed ? railWidth : expandedWidth
            Behavior on Layout.preferredWidth {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
            }
            Layout.fillHeight: true
            collapsed: window.sidebarCollapsed
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
                // a page comes in with a short fade and rise
                transform: Translate { id: pageRise }
                onCurrentIndexChanged: if (!Theme.reducedMotion) pageEnter.restart()
                ParallelAnimation {
                    id: pageEnter
                    NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                    NumberAnimation {
                        target: pageRise; property: "y"; from: 8; to: 0; duration: Theme.durSlow
                        easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve
                    }
                }

                TransfersPage {
                    id: transfersPage
                    onPlayRequested: key => window.playMedia(key, -1)
                    onWatchRequested: (id, file) => window.watchWhenReady(id + ":" + file)
                }
                SearchPage {
                    id: searchPage
                    onWatchRequested: source => transfersPage.openSource(source, true)
                }
                RssPage {}
                MediaPage {
                    playerAvailable: playerView.available
                    onPlayRequested: (key, startAt) => window.playMedia(key, startAt)
                }
                SettingsPage { id: settingsPage }
            }
        }
    }

    // --- Built-in player, over the pages (and over the title strip in full screen) ----------------
    PlayerView {
        id: playerView
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: fullscreen ? parent.top : titleBarArea.bottom
        z: 50

        property int visibilityBefore: Window.Windowed
        onFullscreenToggled: on => {
            titleBarArea.visible = !on
            if (on) {
                visibilityBefore = window.visibility
                window.showFullScreen()
            } else if (visibilityBefore === Window.Maximized) {
                window.showMaximized()
            } else {
                window.showNormal()
            }
        }
        onClosed: watched => window.afterPlayback(watched)
    }

    UiToast {
        id: windowToast
        objectName: "windowToast"
        z: 100
    }

    // Plays a media library item (key "torrentId:fileIndex"): a downloaded file from disk, otherwise through
    // the stream server while it downloads. `startAt` < 0 continues from the saved position.
    // A torrent just added to watch: the library lists it a moment later, then it plays
    property string pendingWatchKey: ""
    function watchWhenReady(key) {
        pendingWatchKey = key
        watchPoll.tries = 0
        watchPoll.restart()
    }
    Timer {
        id: watchPoll
        property int tries: 0
        interval: 200
        repeat: true
        onTriggered: {
            if (MediaLibraryModel.get(window.pendingWatchKey).key !== undefined) {
                stop()
                const key = window.pendingWatchKey
                window.pendingWatchKey = ""
                window.playMedia(key, -1)
            } else if (++tries > 75) {
                stop()
                window.pendingWatchKey = ""
                windowToast.show(qsTr("The video did not show up in the library."), true)
            }
        }
    }

    function playMedia(key, startAt) {
        const m = MediaLibraryModel.get(key)
        if (m.key === undefined)
            return
        if (!playerView.available) {
            if (!MediaLibraryModel.play(key))
                windowToast.show(qsTr("Without the built-in player only downloaded files open."), true)
            return
        }
        const resume = startAt >= 0 ? startAt : WatchHistory.resumePosition(key)
        let url = ""
        let stream = false
        if (m.complete) {
            url = "file:///" + String(m.path).replace(/\\/g, "/")
        } else {
            url = String(StreamManager.open(m.torrentId, m.fileIndex))
            stream = true
            if (url === "") {
                windowToast.show(StreamManager.lastError, true)
                return
            }
            if (StreamManager.enabledSkippedFile(m.torrentId, m.fileIndex) && !StreamManager.isWatchOnly(m.torrentId))
                windowToast.show(qsTr("This file was set to skip; it downloads now."), false)
        }
        const pad = n => (n < 10 ? "0" : "") + n
        const detail = [m.season > 0 ? "S" + pad(m.season) + "E" + pad(m.episode) : "", m.year > 0 ? String(m.year) : "",
                        m.quality === "2160p" ? "4K" : m.quality].filter(t => t !== "").join(" · ")
        playerView.play(m.torrentId, m.fileIndex, m.title, detail, url, stream, resume)
    }

    // The player closed: give the torrent back, then "After watching" (Settings → Streaming)
    function afterPlayback(watchedToEnd) {
        // watched without downloading: nothing is kept
        if (StreamManager.isWatchOnly(playerView.torrentId)) {
            StreamManager.discard(playerView.torrentId)
            return
        }
        if (playerView.streaming)
            StreamManager.close(playerView.torrentId, playerView.fileIndex)
        if (!watchedToEnd)
            return
        const id = playerView.torrentId
        switch (AppSettings.value("afterWatching")) {
        case "delete":
            scheduleDelete(id)
            break
        case "keep":
            break
        default:
            afterWatchDialog.ask(id, playerView.title)
        }
    }

    // Deleting waits 10 s behind an "Undo" toast; nothing is touched before that
    property string pendingDeleteId: ""
    function scheduleDelete(torrentId) {
        if (pendingDeleteId !== "")
            TorrentListModel.remove([pendingDeleteId], true) // an earlier one goes now
        pendingDeleteId = torrentId
        const name = TorrentListModel.get(torrentId).name ?? ""
        toastPurpose = "undoDelete"
        windowToast.show(qsTr("“%1” will be deleted with its files").arg(name), false, qsTr("Undo"))
    }
    // what the toast's action button is for: "undoDelete" or "update"
    property string toastPurpose: ""
    Connections {
        target: windowToast
        function onActionTriggered() {
            if (window.toastPurpose === "update") {
                settingsPage.section = "about"
                window.currentPage = 4
                return
            }
            window.pendingDeleteId = ""
        }
        function onDismissed() {
            if (window.pendingDeleteId === "")
                return
            TorrentListModel.remove([window.pendingDeleteId], true)
            window.pendingDeleteId = ""
        }
    }

    // A newer Flux on GitHub: say so once (unless an undo is waiting on the toast)
    Connections {
        target: Updater
        function onUpdateAvailable(version) {
            if (window.pendingDeleteId !== "")
                return
            window.toastPurpose = "update"
            windowToast.show(qsTr("Flux %1 is available").arg(version.replace(/^v/i, "")), false, qsTr("Details"))
        }
    }

    CreateTorrentDialog {
        id: createTorrentDialog
        onCreatedTorrent: (path, seeding) => windowToast.show(
            seeding ? qsTr("Created and seeding: %1").arg(path) : qsTr("Torrent created: %1").arg(path), false)
    }

    UiDialog {
        id: afterWatchDialog
        objectName: "afterWatchDialog"
        property string torrentId
        function ask(id, name) {
            torrentId = id
            title = qsTr("Watched “%1”").arg(name)
            dontAsk.checked = false
            open()
        }
        description: qsTr("Delete the torrent and its downloaded files, or keep seeding it?")

        function choose(choice) {
            if (dontAsk.checked)
                AppSettings.setValue("afterWatching", choice)
            close()
            if (choice === "delete")
                window.scheduleDelete(torrentId)
        }

        RowLayout {
            spacing: Theme.sp(2)
            UiCheckBox {
                id: dontAsk
                objectName: "afterWatchDontAsk"
                Accessible.name: dontAskLabel.text
            }
            Text {
                id: dontAskLabel
                text: qsTr("Don't ask again")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                TapHandler { onTapped: dontAsk.toggle() }
            }
        }
        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Keep seeding"); onClicked: afterWatchDialog.choose("keep") },
            UiButton { objectName: "afterWatchDelete"; variant: "destructive"; text: qsTr("Delete files"); onClicked: afterWatchDialog.choose("delete") }
        ]
    }
}
