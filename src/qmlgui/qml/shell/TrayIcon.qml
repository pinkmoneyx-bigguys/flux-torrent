import QtQuick
import Qt.labs.platform as Platform
import Flux

// Flux in the notification area: the speeds in the icon's tooltip, a click opens or hides the window, the
// right button opens TrayMenu, and a finished download is announced from there. While it shows, closing
// (and if asked, minimizing) the window only hides it: Flux keeps downloading and seeding.
Item {
    id: root
    visible: false

    // the main window (Main.qml): showFromTray(), hideToTray(), runCommand()
    property var target: null

    function setting(key) {
        return AppSettings.revision >= 0 && AppSettings.value(key) === true
    }
    readonly property bool shown: setting("trayEnabled") && icon.available
    readonly property bool keepsRunning: shown && setting("closeToTray")
    readonly property bool minimizesToTray: shown && setting("minimizeToTray")

    // the first time the window goes there: so it is not mistaken for closed
    function notice() {
        if (shown)
            icon.showMessage(qsTr("Flux keeps running"),
                             qsTr("Downloads and seeding go on in the background. Click the icon to open Flux, or exit from its menu."),
                             Platform.SystemTrayIcon.NoIcon, 6000)
    }

    Platform.SystemTrayIcon {
        id: icon
        visible: root.setting("trayEnabled")
        icon.source: Qt.resolvedUrl("../icons/flux.ico")
        tooltip: "Flux Torrent\n↓ %1   ↑ %2".arg(Format.speed(SessionFacade.downloadRate)).arg(Format.speed(SessionFacade.uploadRate))

        onActivated: reason => {
            if (reason === Platform.SystemTrayIcon.Context)
                menu.visible ? menu.close() : menu.popup()
            else if (reason === Platform.SystemTrayIcon.Trigger)
                root.toggleWindow()
        }
        onMessageClicked: root.target.showFromTray()
    }

    function toggleWindow() {
        if (!target)
            return
        // (a click on the icon has already taken the focus from the window: only whether it shows counts)
        if (target.visible && target.visibility !== Window.Minimized)
            target.hideToTray()
        else
            target.showFromTray()
    }

    TrayMenu {
        id: menu
        target: root.target
        onTriggered: id => {
            switch (id) {
            case "toggle":
                root.toggleWindow()
                break
            case "addTorrent":
            case "addLink":
                root.target.showFromTray()
                root.target.runCommand(id)
                break
            case "quit":
                Qt.quit()
                break
            default:
                root.target.runCommand(id)
            }
        }
    }

    Connections {
        target: Tray
        function onDownloadFinished(name) {
            // the window in front already shows it
            if (root.shown && root.setting("notifyFinished") && !(root.target && root.target.active))
                icon.showMessage(qsTr("Download finished"), name, Platform.SystemTrayIcon.NoIcon, 5000)
        }
    }
}
