import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Settings, laid out like the shadcn settings example: sections on the left, the section's form on the
// right as cards of rows. Every change applies at once through AppSettings (the look through UiSettings).
Surface {
    id: root
    objectName: "page_settings"

    property string title: qsTr("Settings")
    property string hint: qsTr("Application settings will appear here.")
    property string section: "downloads"

    readonly property var sections: [
        { key: "downloads", label: qsTr("Downloads"), icon: Icons.download },
        { key: "speed", label: qsTr("Speed"), icon: Icons.speed },
        { key: "connection", label: qsTr("Connection"), icon: Icons.network },
        { key: "bittorrent", label: qsTr("BitTorrent"), icon: Icons.bittorrent },
        { key: "streaming", label: qsTr("Streaming"), icon: Icons.play },
        { key: "advanced", label: qsTr("Advanced"), icon: Icons.settings },
        { key: "about", label: qsTr("About Flux"), icon: Icons.info }
    ]

    function sectionLabel(key) {
        for (const s of sections) {
            if (s.key === key)
                return s.label
        }
        return ""
    }
    // `revision >= 0` keeps the calling binding subscribed to every settings change
    function on(key) {
        return AppSettings.revision >= 0 && AppSettings.value(key) === true
    }
    function proxyOn() {
        return AppSettings.revision >= 0 && AppSettings.value("proxyType") !== "none"
    }

    // --- Advanced ---
    readonly property var advancedRows: AppSettings.advancedSettings()
    readonly property var advancedGroups: {
        const groups = []
        for (const r of advancedRows) {
            if (groups.indexOf(r.group) < 0)
                groups.push(r.group)
        }
        return groups
    }
    property string advancedFilter: ""
    function matchesFilter(row) {
        const words = advancedFilter.toLowerCase().split(" ").filter(w => w !== "")
        const hay = (row.label + " " + row.key + " " + row.group).toLowerCase()
        return words.every(w => hay.indexOf(w) >= 0)
    }
    function isDefault(row) {
        return AppSettings.revision >= 0 && String(AppSettings.value(row.key)) === String(row["default"])
    }
    function defaultText(row) {
        const d = row["default"]
        if (row.type === "bool")
            return d ? qsTr("on") : qsTr("off")
        if (row.type === "enum")
            return optionLabel(d)
        if (row.type === "string")
            return d === "" ? qsTr("empty") : d
        return row.unit !== "" ? d + " " + unitLabel(row.unit) : String(d)
    }
    function unitLabel(unit) {
        switch (unit) {
        case "KiB": return qsTr("KiB")
        case "MiB": return qsTr("MiB")
        case "min": return qsTr("min")
        case "s": return qsTr("s")
        default: return unit
        }
    }
    function optionLabel(key) {
        switch (key) {
        case "default": return qsTr("Default")
        case "mmap": return qsTr("Memory-mapped files")
        case "posix": return qsTr("POSIX-compliant")
        case "simple": return qsTr("Simple pread/pwrite")
        case "noOsCache": return qsTr("Bypass the OS cache")
        case "osCache": return qsTr("Use the OS cache")
        case "writeThrough": return qsTr("Write-through")
        case "preferTcp": return qsTr("Prefer TCP")
        case "proportional": return qsTr("Peer proportional")
        case "fixedSlots": return qsTr("Fixed slots")
        case "rateBased": return qsTr("By upload rate")
        case "roundRobin": return qsTr("Round-robin")
        case "fastestUpload": return qsTr("Fastest upload")
        case "antiLeech": return qsTr("Anti-leech")
        default: return key
        }
    }

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

    UiDialog {
        id: resetAllDialog
        objectName: "advancedResetDialog"
        title: qsTr("Reset all advanced settings?")
        description: qsTr("Every setting in Advanced goes back to its default. Other sections stay as they are.")
        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Cancel"); onClicked: resetAllDialog.close() },
            UiButton {
                objectName: "advancedResetConfirm"
                variant: "destructive"
                text: qsTr("Reset all")
                onClicked: {
                    AppSettings.resetAdvanced()
                    resetAllDialog.close()
                }
            }
        ]
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            title: root.title
            subtitle: root.sectionLabel(root.section)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // --- Section nav ----------------------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: false
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                Layout.topMargin: Theme.sp(4)
                Layout.leftMargin: Theme.sp(4)
                spacing: 2

                Repeater {
                    model: root.sections
                    AbstractButton {
                        id: navItem
                        required property var modelData
                        readonly property bool current: root.section === modelData.key
                        objectName: "settingsNav_" + modelData.key
                        Layout.fillWidth: true
                        implicitHeight: 34
                        leftPadding: 10
                        rightPadding: 10
                        hoverEnabled: true
                        focusPolicy: Qt.StrongFocus
                        text: modelData.label
                        onClicked: root.section = modelData.key

                        Accessible.role: Accessible.PageTab
                        Accessible.name: text
                        Accessible.selected: current

                        background: Rectangle {
                            radius: Theme.radiusCtl
                            color: navItem.current ? Theme.selected : navItem.hovered ? Theme.hover : Theme.alpha(Theme.hover, 0)
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                            border.width: navItem.visualFocus ? 2 : 0
                            border.color: Theme.ring
                        }
                        contentItem: RowLayout {
                            spacing: Theme.sp(2)
                            Icon {
                                path: navItem.modelData.icon
                                size: 16
                                strokeWidth: 1.75
                                color: navItem.current ? Theme.text : Theme.textDim
                            }
                            Text {
                                Layout.fillWidth: true
                                text: navItem.text
                                color: navItem.current ? Theme.text : Theme.alpha(Theme.text, 0.8)
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                                font.weight: navItem.current ? Font.Medium : Font.Normal
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // --- Form -----------------------------------------------------------------------------
            Flickable {
                id: form
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: content.implicitHeight + 2 * Theme.sp(6)
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                // back to the top when switching sections
                Connections {
                    target: root
                    function onSectionChanged() {
                        form.contentY = 0
                    }
                }

                ColumnLayout {
                    id: content
                    x: Theme.sp(6)
                    y: Theme.sp(4)
                    width: Math.min(form.width - 2 * Theme.sp(6), 760)
                    spacing: Theme.sp(8)

                    // ===== Downloads =====
                    ColumnLayout {
                        visible: root.section === "downloads"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        SettingsGroup {
                            title: qsTr("Where files go")
                            SettingRow {
                                key: "savePath"
                                type: "path"
                                label: qsTr("Save to")
                                description: qsTr("The default folder for new torrents.")
                            }
                            SettingRow {
                                key: "downloadPathEnabled"
                                label: qsTr("Keep incomplete torrents elsewhere")
                                description: qsTr("Files move to the save folder when they finish.")
                            }
                            SettingRow {
                                visible: root.on("downloadPathEnabled")
                                key: "downloadPath"
                                type: "path"
                                label: qsTr("Incomplete torrents")
                            }
                            SettingRow {
                                key: "appendExtension"
                                label: qsTr("Mark incomplete files")
                                description: qsTr("Adds .!qB to files until they are complete.")
                            }
                            SettingRow {
                                key: "preallocation"
                                label: qsTr("Reserve disk space up front")
                                description: qsTr("Allocates the full size when a download starts.")
                            }
                        }

                        SettingsGroup {
                            title: qsTr("When adding a torrent")
                            SettingRow {
                                key: "contentLayout"
                                type: "select"
                                label: qsTr("Content layout")
                                description: qsTr("Whether a torrent's files get a folder of their own.")
                                options: [
                                    { key: "original", label: qsTr("As in the torrent") },
                                    { key: "subfolder", label: qsTr("Always a subfolder") },
                                    { key: "noSubfolder", label: qsTr("Never a subfolder") }
                                ]
                            }
                            SettingRow {
                                key: "addStopped"
                                label: qsTr("Add stopped")
                                description: qsTr("New torrents wait until you start them.")
                            }
                            SettingRow {
                                key: "addToQueueTop"
                                label: qsTr("Put new torrents first in the queue")
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Double-click in Transfers")
                            SettingRow {
                                key: "dblClickFinished"
                                type: "select"
                                label: qsTr("On a finished torrent")
                                options: [
                                    { key: "open", label: qsTr("Open the folder") },
                                    { key: "toggle", label: qsTr("Start or stop") },
                                    { key: "none", label: qsTr("Nothing") }
                                ]
                            }
                            SettingRow {
                                key: "dblClickRunning"
                                type: "select"
                                label: qsTr("On a downloading torrent")
                                options: [
                                    { key: "toggle", label: qsTr("Start or stop") },
                                    { key: "open", label: qsTr("Open the folder") },
                                    { key: "none", label: qsTr("Nothing") }
                                ]
                            }
                        }
                    }

                    // ===== Speed =====
                    ColumnLayout {
                        visible: root.section === "speed"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        SettingsGroup {
                            title: qsTr("Speed limits")
                            description: qsTr("0 means unlimited.")
                            SettingRow { key: "dlLimit"; type: "number"; suffix: qsTr("KiB/s"); label: qsTr("Download") }
                            SettingRow { key: "upLimit"; type: "number"; suffix: qsTr("KiB/s"); label: qsTr("Upload") }
                        }
                        SettingsGroup {
                            title: qsTr("Alternative limits")
                            description: qsTr("A second pair of limits you switch with the turtle in the title bar.")
                            SettingRow {
                                key: "altSpeedEnabled"
                                label: qsTr("Use alternative limits now")
                            }
                            SettingRow { key: "altDlLimit"; type: "number"; suffix: qsTr("KiB/s"); label: qsTr("Download") }
                            SettingRow { key: "altUpLimit"; type: "number"; suffix: qsTr("KiB/s"); label: qsTr("Upload") }
                            SettingRow {
                                key: "schedulerEnabled"
                                label: qsTr("Switch on a schedule")
                                description: qsTr("Alternative limits turn on by themselves in the hours below.")
                            }
                            SettingRow {
                                visible: root.on("schedulerEnabled")
                                key: "schedulerFrom"
                                type: "text"
                                controlWidth: 110
                                placeholder: "08:00"
                                label: qsTr("From")
                                description: qsTr("24-hour time, HH:MM.")
                            }
                            SettingRow {
                                visible: root.on("schedulerEnabled")
                                key: "schedulerTo"
                                type: "text"
                                controlWidth: 110
                                placeholder: "20:00"
                                label: qsTr("To")
                                description: qsTr("An end before the start runs past midnight.")
                            }
                            SettingRow {
                                visible: root.on("schedulerEnabled")
                                key: "schedulerDays"
                                type: "select"
                                label: qsTr("On")
                                options: [
                                    { key: "everyDay", label: qsTr("Every day") },
                                    { key: "weekday", label: qsTr("Weekdays") },
                                    { key: "weekend", label: qsTr("Weekends") },
                                    { key: "monday", label: qsTr("Monday") },
                                    { key: "tuesday", label: qsTr("Tuesday") },
                                    { key: "wednesday", label: qsTr("Wednesday") },
                                    { key: "thursday", label: qsTr("Thursday") },
                                    { key: "friday", label: qsTr("Friday") },
                                    { key: "saturday", label: qsTr("Saturday") },
                                    { key: "sunday", label: qsTr("Sunday") }
                                ]
                            }
                        }
                        SettingsGroup {
                            title: qsTr("How limits apply")
                            SettingRow { key: "utpRateLimited"; label: qsTr("Limit µTP connections too") }
                            SettingRow { key: "includeOverhead"; label: qsTr("Count protocol overhead") }
                            SettingRow {
                                key: "ignoreLimitsOnLAN"
                                label: qsTr("No limits on the local network")
                            }
                        }
                    }

                    // ===== Connection =====
                    ColumnLayout {
                        visible: root.section === "connection"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        SettingsGroup {
                            title: qsTr("Listening port")
                            SettingRow {
                                id: portRow
                                key: "port"
                                type: "number"
                                controlWidth: 110
                                label: qsTr("Port for incoming connections")
                                description: qsTr("Other peers connect to you on this port.")
                                UiButton {
                                    variant: "outline"
                                    text: qsTr("Random")
                                    onClicked: portRow.commit(AppSettings.randomPort())
                                }
                            }
                            SettingRow {
                                key: "upnp"
                                label: qsTr("Open the port on the router")
                                description: qsTr("UPnP / NAT-PMP forwarding.")
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Connections")
                            description: qsTr("-1 means unlimited.")
                            SettingRow {
                                key: "protocol"
                                type: "select"
                                label: qsTr("Peer protocol")
                                options: [
                                    { key: "both", label: qsTr("TCP and µTP") },
                                    { key: "tcp", label: "TCP" },
                                    { key: "utp", label: "µTP" }
                                ]
                            }
                            SettingRow { key: "maxConnections"; type: "number"; label: qsTr("Connections in total") }
                            SettingRow { key: "maxConnectionsPerTorrent"; type: "number"; label: qsTr("Connections per torrent") }
                            SettingRow { key: "maxUploads"; type: "number"; label: qsTr("Upload slots in total") }
                            SettingRow { key: "maxUploadsPerTorrent"; type: "number"; label: qsTr("Upload slots per torrent") }
                        }
                        SettingsGroup {
                            title: qsTr("Proxy")
                            SettingRow {
                                key: "proxyType"
                                type: "select"
                                label: qsTr("Proxy")
                                options: [
                                    { key: "none", label: qsTr("None") },
                                    { key: "http", label: "HTTP" },
                                    { key: "socks5", label: "SOCKS5" },
                                    { key: "socks4", label: "SOCKS4" }
                                ]
                            }
                            SettingRow { visible: root.proxyOn(); key: "proxyHost"; type: "text"; label: qsTr("Host"); placeholder: "127.0.0.1" }
                            SettingRow { visible: root.proxyOn(); key: "proxyPort"; type: "number"; controlWidth: 110; label: qsTr("Port") }
                            SettingRow { visible: root.proxyOn(); key: "proxyAuth"; label: qsTr("Sign in to the proxy") }
                            SettingRow { visible: root.proxyOn() && root.on("proxyAuth"); key: "proxyUser"; type: "text"; label: qsTr("User name") }
                            SettingRow { visible: root.proxyOn() && root.on("proxyAuth"); key: "proxyPassword"; type: "password"; label: qsTr("Password") }
                            SettingRow {
                                visible: root.proxyOn()
                                key: "proxyPeers"
                                label: qsTr("Connect to peers through the proxy")
                                description: qsTr("Otherwise only trackers and downloads use it.")
                            }
                        }
                    }

                    // ===== BitTorrent =====
                    ColumnLayout {
                        visible: root.section === "bittorrent"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        SettingsGroup {
                            title: qsTr("Finding peers and privacy")
                            SettingRow { key: "dht"; label: qsTr("DHT"); description: qsTr("Finds peers without trackers.") }
                            SettingRow { key: "pex"; label: qsTr("Peer exchange"); description: qsTr("Peers share the peers they know.") }
                            SettingRow { key: "lsd"; label: qsTr("Local peer discovery"); description: qsTr("Finds peers on your local network.") }
                            SettingRow {
                                key: "encryption"
                                type: "select"
                                label: qsTr("Encryption")
                                options: [
                                    { key: "prefer", label: qsTr("Allow") },
                                    { key: "require", label: qsTr("Require") },
                                    { key: "disable", label: qsTr("Turn off") }
                                ]
                            }
                            SettingRow {
                                key: "anonymous"
                                label: qsTr("Anonymous mode")
                                description: qsTr("Hides the client name and version from peers and trackers.")
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Queue")
                            SettingRow {
                                key: "queueing"
                                label: qsTr("Limit active torrents")
                                description: qsTr("Torrents beyond the limits wait in the queue.")
                            }
                            SettingRow { visible: root.on("queueing"); key: "maxActiveDownloads"; type: "number"; label: qsTr("Active downloads") }
                            SettingRow { visible: root.on("queueing"); key: "maxActiveUploads"; type: "number"; label: qsTr("Active uploads") }
                            SettingRow { visible: root.on("queueing"); key: "maxActiveTorrents"; type: "number"; label: qsTr("Active torrents") }
                            SettingRow {
                                visible: root.on("queueing")
                                key: "ignoreSlow"
                                label: qsTr("Don't count slow torrents")
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Seeding limits")
                            description: qsTr("What happens when a torrent has seeded enough.")
                            SettingRow { key: "ratioLimitEnabled"; label: qsTr("Stop at a ratio") }
                            SettingRow { visible: root.on("ratioLimitEnabled"); key: "ratioLimit"; type: "decimal"; label: qsTr("Ratio") }
                            SettingRow { key: "seedTimeEnabled"; label: qsTr("Stop after seeding for a while") }
                            SettingRow {
                                visible: root.on("seedTimeEnabled")
                                key: "seedTimeMinutes"
                                type: "number"
                                suffix: qsTr("min")
                                label: qsTr("Seeding time")
                            }
                            SettingRow {
                                visible: root.on("ratioLimitEnabled") || root.on("seedTimeEnabled")
                                key: "shareAction"
                                type: "select"
                                label: qsTr("Then")
                                options: [
                                    { key: "stop", label: qsTr("Stop the torrent") },
                                    { key: "remove", label: qsTr("Remove the torrent") },
                                    { key: "removeContent", label: qsTr("Remove it and its files") },
                                    { key: "superSeed", label: qsTr("Switch to super-seeding") }
                                ]
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Trackers")
                            SettingRow {
                                key: "addTrackersEnabled"
                                label: qsTr("Add these trackers to new torrents")
                            }
                            SettingRow {
                                visible: root.on("addTrackersEnabled")
                                key: "additionalTrackers"
                                type: "textarea"
                                label: qsTr("Trackers")
                                description: qsTr("One URL per line.")
                                placeholder: "udp://tracker.example.org:1337/announce"
                            }
                        }
                    }

                    // ===== Streaming =====
                    ColumnLayout {
                        visible: root.section === "streaming"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        SettingsGroup {
                            title: qsTr("Watching while downloading")
                            SettingRow {
                                key: "streamMode"
                                external: true
                                externalValue: StreamManager.mode
                                onExternalCommit: value => StreamManager.mode = value
                                type: "select"
                                label: qsTr("Stream mode")
                                description: StreamManager.mode === "fast" ? qsTr("Starts soonest; may pause on a slow swarm.")
                                           : StreamManager.mode === "economy" ? qsTr("Reads only a little ahead; the rest of the torrent keeps its pace.")
                                           : qsTr("Keeps about four minutes downloaded ahead.")
                                options: [
                                    { key: "fast", label: qsTr("Fast start") },
                                    { key: "smooth", label: qsTr("Smooth") },
                                    { key: "economy", label: qsTr("Economy") }
                                ]
                            }
                            SettingRow {
                                key: "afterWatching"
                                type: "select"
                                label: qsTr("After watching")
                                description: qsTr("What to do with a torrent once its video is watched to the end.")
                                options: [
                                    { key: "ask", label: qsTr("Ask") },
                                    { key: "keep", label: qsTr("Keep seeding") },
                                    { key: "delete", label: qsTr("Delete the files") }
                                ]
                            }
                            SettingRow {
                                key: "watchCache"
                                external: true
                                externalValue: StreamManager.cachePath
                                onExternalCommit: value => StreamManager.cachePath = value
                                type: "path"
                                label: qsTr("Watch without downloading: temporary folder")
                                description: qsTr("Where pieces wait while they play. The torrent and its files are removed when the player closes.")
                            }
                        }
                        SettingsGroup {
                            title: qsTr("Player")
                            SettingRow {
                                key: "openWith"
                                external: true
                                externalValue: "builtin"
                                type: "select"
                                label: qsTr("Open videos with")
                                description: qsTr("mpv and VLC are coming: Flux needs to know where you stopped and when you close them.")
                                options: [
                                    { key: "builtin", label: qsTr("Built-in player") },
                                    { key: "mpv", label: qsTr("mpv — soon"), disabled: true },
                                    { key: "vlc", label: qsTr("VLC — soon"), disabled: true }
                                ]
                                onExternalCommit: value => {} // only the built-in player for now
                            }
                            SettingRow {
                                key: "hardwareDecoding"
                                label: qsTr("Hardware decoding")
                                description: qsTr("Decodes video on the graphics card. Turn off if the picture breaks up.")
                            }
                        }
                    }

                    // ===== About =====
                    ColumnLayout {
                        objectName: "aboutSection"
                        visible: root.section === "about"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        // who and which version
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.sp(4)

                            Rectangle {
                                Layout.alignment: Qt.AlignTop
                                implicitWidth: 56
                                implicitHeight: 56
                                radius: 14
                                color: Theme.primary
                                Icon {
                                    anchors.centerIn: parent
                                    path: Icons.logo
                                    size: 28
                                    strokeWidth: 2.4
                                    color: Theme.primaryText
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Row {
                                    spacing: 6
                                    Accessible.role: Accessible.Heading
                                    Accessible.name: AppInfo.name
                                    Text {
                                        id: aboutBrand
                                        text: "Flux"
                                        color: Theme.text
                                        font.family: Theme.fontText
                                        font.pixelSize: 20
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.baseline: aboutBrand.baseline
                                        text: "Torrent"
                                        color: Theme.alpha(Theme.text, 0.82)
                                        font.family: Theme.fontText
                                        font.pixelSize: 20
                                        font.weight: Font.Light
                                    }
                                }
                                Text {
                                    objectName: "aboutVersion"
                                    text: qsTr("Version %1").arg(AppInfo.version)
                                          + (AppInfo.commit !== "" ? " · " + AppInfo.commit : "")
                                    color: Theme.textDim
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.textSm
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("A torrent client for Windows built on qBittorrent %1, with a player that streams while it downloads.").arg(AppInfo.baseVersion)
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        // updates
                        SettingsGroup {
                            title: qsTr("Updates")
                            description: AppInfo.repository !== ""
                                         ? qsTr("New versions are published as releases on GitHub.")
                                         : qsTr("This build does not say where its releases are published.")

                            Item {
                                width: parent.width
                                implicitHeight: updateRow.implicitHeight + 2 * Theme.sp(4)

                                RowLayout {
                                    id: updateRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.sp(4)
                                    anchors.rightMargin: Theme.sp(4)
                                    spacing: Theme.sp(3)

                                    Rectangle {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        radius: 8
                                        color: Theme.alpha(Updater.status === "available" ? Theme.download
                                                           : Updater.status === "error" ? Theme.error : Theme.upload, 0.14)
                                        Icon {
                                            id: updateGlyph
                                            anchors.centerIn: parent
                                            path: Updater.status === "available" ? Icons.download
                                                : Updater.status === "error" ? Icons.alert
                                                : Updater.status === "checking" ? Icons.refresh : Icons.check
                                            size: 16
                                            strokeWidth: 2
                                            color: Updater.status === "available" ? Theme.download
                                                 : Updater.status === "error" ? Theme.error : Theme.upload
                                            RotationAnimation on rotation {
                                                running: Updater.status === "checking" && !Theme.reducedMotion
                                                from: 0
                                                to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                                // the next glyph stands upright
                                                onRunningChanged: if (!running) updateGlyph.rotation = 0
                                            }
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            objectName: "updateStatus"
                                            Layout.fillWidth: true
                                            text: {
                                                switch (Updater.status) {
                                                case "checking": return qsTr("Checking for updates…")
                                                case "available": return qsTr("Version %1 is available").arg(Updater.latestVersion.replace(/^v/i, ""))
                                                case "upToDate": return qsTr("You have the latest version")
                                                case "error": return qsTr("Could not check for updates")
                                                default: return qsTr("Updates have not been checked yet")
                                                }
                                            }
                                            color: Theme.text
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.textSm
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: Updater.status === "error" ? Updater.error
                                                : Updater.status === "available" && Updater.downloadName !== ""
                                                  ? qsTr("%1 · %2").arg(Updater.downloadName).arg(Format.size(Updater.downloadSize))
                                                : Updater.lastChecked.getTime && !isNaN(Updater.lastChecked.getTime())
                                                  ? qsTr("Checked %1").arg(Updater.lastChecked.toLocaleString(Qt.locale(), Locale.ShortFormat))
                                                  : ""
                                            visible: text !== ""
                                            color: Updater.status === "error" ? Theme.error : Theme.textDim
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.textXs
                                            elide: Text.ElideRight
                                        }
                                    }
                                    UiButton {
                                        visible: Updater.status === "available"
                                        iconPath: Icons.download
                                        text: qsTr("Download")
                                        onClicked: Updater.openDownload()
                                    }
                                    UiButton {
                                        objectName: "checkUpdates"
                                        variant: "outline"
                                        enabled: Updater.status !== "checking" && AppInfo.repository !== ""
                                        text: qsTr("Check now")
                                        onClicked: Updater.check()
                                    }
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: Theme.border
                                }
                            }

                            // what is new in it
                            Item {
                                visible: Updater.status === "available" && Updater.notes !== ""
                                width: parent.width
                                implicitHeight: visible ? notesText.implicitHeight + 2 * Theme.sp(4) : 0
                                Text {
                                    id: notesText
                                    x: Theme.sp(4)
                                    y: Theme.sp(4)
                                    width: parent.width - 2 * Theme.sp(4)
                                    text: Updater.notes
                                    textFormat: Text.MarkdownText
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 12
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 1
                                    color: Theme.border
                                }
                            }

                            SettingRow {
                                key: "autoUpdateCheck"
                                external: true
                                externalValue: Updater.autoCheck
                                onExternalCommit: value => Updater.autoCheck = value
                                label: qsTr("Check for updates automatically")
                                description: qsTr("Once a day, when Flux starts.")
                            }
                        }

                        // links
                        SettingsGroup {
                            visible: AppInfo.repository !== ""
                            title: qsTr("Project")
                            Flow {
                                x: Theme.sp(4)
                                width: parent.width - 2 * Theme.sp(4)
                                topPadding: Theme.sp(4)
                                bottomPadding: Theme.sp(4)
                                spacing: Theme.sp(2)
                                UiButton {
                                    variant: "outline"
                                    iconPath: Icons.externalLink
                                    text: qsTr("GitHub")
                                    onClicked: AppInfo.openUrl(AppInfo.repositoryUrl)
                                }
                                UiButton {
                                    variant: "outline"
                                    iconPath: Icons.download
                                    text: qsTr("All releases")
                                    onClicked: AppInfo.openUrl(AppInfo.releasesUrl)
                                }
                                UiButton {
                                    variant: "outline"
                                    iconPath: Icons.alert
                                    text: qsTr("Report a problem")
                                    onClicked: AppInfo.openUrl(AppInfo.issuesUrl)
                                }
                            }
                        }

                        // what it is made of
                        SettingsGroup {
                            title: qsTr("Components")
                            Repeater {
                                model: [
                                    { label: "qBittorrent", value: AppInfo.baseVersion },
                                    { label: "libtorrent", value: AppInfo.libtorrentVersion },
                                    { label: "Qt", value: AppInfo.qtVersion },
                                    { label: "Boost", value: AppInfo.boostVersion },
                                    { label: "OpenSSL", value: AppInfo.opensslVersion },
                                    { label: "zlib", value: AppInfo.zlibVersion }
                                ]
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    implicitHeight: 40
                                    Text {
                                        x: Theme.sp(4)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        color: Theme.text
                                        font.family: Theme.fontText
                                        font.pixelSize: Theme.textSm
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.sp(4)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.value || "—"
                                        color: Theme.textDim
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.textSm
                                    }
                                    Rectangle {
                                        visible: index < 5
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: 1
                                        color: Theme.border
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.sp(2)
                            UiButton {
                                variant: "outline"
                                iconPath: Icons.file
                                text: qsTr("Copy version info")
                                onClicked: {
                                    AppInfo.copyDiagnostics()
                                    copiedNote.visible = true
                                }
                            }
                            UiButton {
                                visible: AppInfo.profilePath !== ""
                                variant: "outline"
                                iconPath: Icons.folder
                                text: qsTr("Open the profile folder")
                                onClicked: AppInfo.openProfileFolder()
                            }
                            Text {
                                id: copiedNote
                                visible: false
                                text: qsTr("Copied")
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Flux is free software built on qBittorrent and distributed under the GNU General Public License, version 2 or later. It comes with no warranty.")
                            color: Theme.textFaint
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            wrapMode: Text.Wrap
                        }
                    }

                    // ===== Advanced =====
                    ColumnLayout {
                        visible: root.section === "advanced"
                        Layout.fillWidth: true
                        spacing: Theme.sp(8)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.sp(3)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: qsTr("Advanced")
                                    color: Theme.text
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textBase
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Fine-tuning of qBittorrent and libtorrent. The defaults suit almost everyone.")
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    wrapMode: Text.Wrap
                                }
                            }
                            UiInput {
                                objectName: "advancedSearch"
                                Layout.preferredWidth: 220
                                iconPath: Icons.search
                                placeholderText: qsTr("Find a setting…")
                                onTextChanged: root.advancedFilter = text
                            }
                            UiButton {
                                objectName: "advancedResetAll"
                                variant: "outline"
                                iconPath: Icons.refresh
                                text: qsTr("Reset all")
                                onClicked: resetAllDialog.open()
                            }
                        }

                        Repeater {
                            model: root.advancedGroups

                            SettingsGroup {
                                id: advGroup
                                required property var modelData
                                readonly property var groupRows: root.advancedRows.filter(r => r.group === modelData && root.matchesFilter(r))
                                visible: groupRows.length > 0
                                title: modelData

                                Repeater {
                                    model: advGroup.groupRows
                                    SettingRow {
                                        required property var modelData
                                        key: modelData.key
                                        label: modelData.label
                                        type: modelData.type === "int" ? "number" : modelData.type === "bool" ? "switch"
                                            : modelData.type === "enum" ? "select" : "text"
                                        suffix: root.unitLabel(modelData.unit)
                                        controlWidth: modelData.type === "string" ? 300 : modelData.type === "enum" ? 200 : 140
                                        options: modelData.options.map(o => ({ key: o.key, label: root.optionLabel(o.key) }))
                                        description: (modelData.restart ? qsTr("Applies after a restart. ") : "")
                                                     + (root.isDefault(modelData) ? "" : qsTr("Default: %1").arg(root.defaultText(modelData)))
                                        UiButton {
                                            visible: !root.isDefault(modelData)
                                            size: "iconSm"
                                            variant: "ghost"
                                            iconPath: Icons.refresh
                                            Accessible.name: qsTr("Reset %1").arg(modelData.label)
                                            onClicked: AppSettings.resetValue(modelData.key)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.advancedRows.every(r => !root.matchesFilter(r))
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("No setting matches.")
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }
        }
    }

    component SectionTitle: ColumnLayout {
        property string title
        property string text
        Layout.fillWidth: true
        spacing: 2
        Text {
            text: parent.title
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textBase
            font.weight: Font.DemiBold
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Text {
            Layout.fillWidth: true
            text: parent.text
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            wrapMode: Text.Wrap
        }
    }
}
