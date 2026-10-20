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
    property string section: "interface"

    readonly property var sections: [
        { key: "interface", label: qsTr("Interface"), icon: Icons.uiPanel },
        { key: "downloads", label: qsTr("Downloads"), icon: Icons.download },
        { key: "speed", label: qsTr("Speed"), icon: Icons.speed },
        { key: "connection", label: qsTr("Connection"), icon: Icons.network },
        { key: "bittorrent", label: qsTr("BitTorrent"), icon: Icons.bittorrent }
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

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

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
                            color: navItem.current ? Theme.selected : navItem.hovered ? Theme.hover : "transparent"
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

                    // ===== Interface =====
                    ColumnLayout {
                        visible: root.section === "interface"
                        Layout.fillWidth: true
                        spacing: Theme.sp(4)

                        SectionTitle {
                            title: qsTr("Appearance")
                            text: qsTr("Choose how Flux looks. The change applies right away.")
                        }
                        ThemePicker {}
                    }

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
                                description: qsTr("Uses the schedule from your qBittorrent settings.")
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
