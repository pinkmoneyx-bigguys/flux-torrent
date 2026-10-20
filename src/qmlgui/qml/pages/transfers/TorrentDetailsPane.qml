import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The bottom pane of Transfers for one torrent: line tabs General / Files / Trackers / Peers.
// Data comes from TorrentDetails, refreshed every second while the pane is visible.
Item {
    id: pane

    property alias torrentId: details.torrentId
    property string tab: "general"
    signal closeRequested()

    TorrentDetails {
        id: details
        active: pane.visible
    }

    readonly property var info: details.info

    // separator against the table above
    Rectangle {
        width: parent.width
        height: 1
        y: Theme.sp(4)
        color: Theme.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.sp(4) + 1
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(4)
            spacing: Theme.sp(4)

            UiTabs {
                variant: "line"
                currentKey: pane.tab
                model: [
                    { key: "general", label: qsTr("General") },
                    { key: "files", label: qsTr("Files"), count: details.files.length },
                    { key: "trackers", label: qsTr("Trackers"), count: details.trackers.length },
                    { key: "peers", label: qsTr("Peers"), count: details.peers.length }
                ]
                onActivated: key => pane.tab = key
            }
            Text {
                Layout.fillWidth: true
                text: pane.info.name ?? ""
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }
            UiButton {
                size: "iconSm"
                variant: "ghost"
                iconPath: Icons.x
                Accessible.name: qsTr("Close details")
                onClicked: pane.closeRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["general", "files", "trackers", "peers"].indexOf(pane.tab)

            // --- General ------------------------------------------------------------------------
            Flickable {
                clip: true
                contentHeight: general.implicitHeight + 2 * Theme.sp(4)
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: general
                    x: Theme.sp(6)
                    y: Theme.sp(4)
                    width: parent.width - 2 * Theme.sp(6)
                    spacing: Theme.sp(4)

                    // piece map: one bar per slice of the torrent, brighter the more of it is present
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Pieces")
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textXs
                                font.weight: Font.Medium
                            }
                            Text {
                                text: (pane.info.piecesCount ?? 0) > 0
                                      ? qsTr("%1 of %2 × %3").arg(pane.info.piecesHave).arg(pane.info.piecesCount).arg(Format.size(pane.info.pieceLength))
                                      : Math.floor((pane.info.progress ?? 0) * 1000) / 10 + "%"
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textXs
                                font.features: { "tnum": 1 }
                            }
                        }
                        Item {
                            id: pieceBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            readonly property var buckets: details.pieces.length > 0 ? details.pieces
                                                          : [pane.info.progress ?? 0]
                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: Theme.muted
                            }
                            Row {
                                anchors.fill: parent
                                anchors.margins: 2
                                Repeater {
                                    model: pieceBar.buckets.length > 1 ? pieceBar.buckets : 0
                                    Rectangle {
                                        required property var modelData
                                        width: (pieceBar.width - 4) / pieceBar.buckets.length
                                        height: pieceBar.height - 4
                                        // missing slices stay transparent but keep their place in the row
                                        color: modelData > 0 ? Theme.alpha(TorrentStatus.color(pane.info.state ?? ""), 0.25 + 0.75 * modelData)
                                                             : "transparent"
                                    }
                                }
                            }
                            // without a piece map: a plain bar of the progress
                            Rectangle {
                                visible: pieceBar.buckets.length <= 1
                                x: 2; y: 2
                                width: (parent.width - 4) * (pane.info.progress ?? 0)
                                height: parent.height - 4
                                radius: 3
                                color: TorrentStatus.color(pane.info.state ?? "")
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor(width / 260))
                        columnSpacing: Theme.sp(6)
                        rowSpacing: Theme.sp(3)

                        Fact { label: qsTr("Status"); value: TorrentStatus.label(pane.info.state ?? "") }
                        Fact { label: qsTr("Size"); value: Format.size(pane.info.size ?? 0) }
                        Fact { label: qsTr("Downloaded"); value: Format.size(pane.info.downloaded ?? 0) }
                        Fact { label: qsTr("Uploaded"); value: Format.size(pane.info.uploaded ?? 0) }
                        Fact { label: qsTr("Ratio"); value: Format.ratio(pane.info.ratio ?? 0) }
                        Fact { label: qsTr("Remaining"); value: (pane.info.progress ?? 0) >= 1 ? "—" : Format.eta(pane.info.eta ?? -1) }
                        Fact {
                            label: qsTr("Seeds")
                            value: qsTr("%1 (%2 in swarm)").arg(pane.info.seeds ?? 0).arg(pane.info.seedsTotal ?? 0)
                        }
                        Fact {
                            label: qsTr("Peers")
                            value: qsTr("%1 (%2 in swarm)").arg(pane.info.peers ?? 0).arg(pane.info.peersTotal ?? 0)
                        }
                        Fact {
                            label: qsTr("Added")
                            value: pane.info.added ? pane.info.added.toLocaleString(Qt.locale(), Locale.ShortFormat) : "—"
                        }
                        Fact {
                            label: qsTr("Availability")
                            value: pane.info.availability !== undefined && pane.info.availability >= 0
                                   ? Number(pane.info.availability).toLocaleString(Qt.locale(), "f", 2) : "—"
                        }
                        Fact { label: qsTr("Category"); value: pane.info.category || "—" }
                        Fact { label: qsTr("Tags"); value: pane.info.tags || "—" }
                        Fact {
                            label: qsTr("Save path")
                            value: pane.info.savePath || "—"
                            Layout.columnSpan: Math.min(2, parent.columns)
                            mono: true
                        }
                        Fact {
                            label: qsTr("Info hash")
                            value: pane.info.hash || pane.info.torrentId || "—"
                            Layout.columnSpan: Math.min(2, parent.columns)
                            mono: true
                        }
                        Fact {
                            visible: (pane.info.comment ?? "") !== ""
                            label: qsTr("Comment")
                            value: pane.info.comment ?? ""
                            Layout.columnSpan: parent.columns
                        }
                        Fact {
                            visible: (pane.info.error ?? "") !== ""
                            label: qsTr("Error")
                            value: pane.info.error ?? ""
                            valueColor: Theme.error
                            Layout.columnSpan: parent.columns
                        }
                    }
                }
            }

            // --- Files --------------------------------------------------------------------------
            DetailList {
                emptyText: (pane.info.hasMetadata ?? true) ? qsTr("No files") : qsTr("Waiting for metadata…")
                model: details.files
                columns: [
                    { title: qsTr("Name"), fill: true },
                    { title: qsTr("Size"), width: 96, right: true },
                    { title: qsTr("Progress"), width: 150 },
                    { title: qsTr("Priority"), width: 120 }
                ]
                delegate: DetailRow {
                    id: fileRow
                    required property var modelData
                    DetailCell { Layout.fillWidth: true; text: fileRow.modelData.path ?? fileRow.modelData.name; elide: Text.ElideMiddle }
                    DetailCell { Layout.preferredWidth: 96; alignRight: true; text: Format.size(fileRow.modelData.size) }
                    RowLayout {
                        Layout.preferredWidth: 150
                        Layout.maximumWidth: 150
                        Layout.leftMargin: 16
                        spacing: Theme.sp(2)
                        UiProgress {
                            Layout.preferredWidth: 80
                            value: fileRow.modelData.progress
                            color: fileRow.modelData.priority === 0 ? Theme.textFaint : TorrentStatus.color(pane.info.state ?? "")
                            active: fileRow.modelData.priority !== 0 && fileRow.modelData.progress < 1
                                    && TorrentStatus.isActive(pane.info.state ?? "")
                        }
                        DetailCell {
                            Layout.fillWidth: true
                            text: Math.floor(fileRow.modelData.progress * 1000) / 10 + "%"
                            color: Theme.textDim
                        }
                    }
                    Item {
                        Layout.preferredWidth: 120
                        Layout.fillHeight: true
                        Layout.leftMargin: 16
                        UiButton {
                            anchors.verticalCenter: parent.verticalCenter
                            size: "sm"
                            variant: "ghost"
                            implicitHeight: 26
                            text: pane.priorityLabel(fileRow.modelData.priority)
                            onClicked: {
                                priorityMenu.fileIndex = fileRow.modelData.index
                                priorityMenu.popup()
                            }
                        }
                    }
                }
            }

            // --- Trackers -----------------------------------------------------------------------
            DetailList {
                emptyText: qsTr("No trackers")
                model: details.trackers
                columns: [
                    { title: qsTr("URL"), fill: true },
                    { title: qsTr("Status"), width: 140 },
                    { title: qsTr("Seeds"), width: 72, right: true },
                    { title: qsTr("Peers"), width: 72, right: true },
                    { title: qsTr("Message"), width: 240 }
                ]
                delegate: DetailRow {
                    id: trackerRow
                    required property var modelData
                    DetailCell { Layout.fillWidth: true; text: trackerRow.modelData.url; elide: Text.ElideMiddle }
                    Item {
                        Layout.preferredWidth: 140
                        Layout.fillHeight: true
                        Layout.leftMargin: 16
                        UiBadge {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pane.trackerLabel(trackerRow.modelData.status)
                            dotColor: pane.trackerColor(trackerRow.modelData.status)
                        }
                    }
                    DetailCell { Layout.preferredWidth: 72; alignRight: true; text: trackerRow.modelData.seeds >= 0 ? trackerRow.modelData.seeds : "—" }
                    DetailCell { Layout.preferredWidth: 72; alignRight: true; text: trackerRow.modelData.peers >= 0 ? trackerRow.modelData.peers : "—" }
                    DetailCell { Layout.preferredWidth: 240; Layout.leftMargin: 16; text: trackerRow.modelData.message || "—"; color: Theme.textDim }
                }
            }

            // --- Peers --------------------------------------------------------------------------
            DetailList {
                emptyText: qsTr("No connected peers")
                model: details.peers
                columns: [
                    { title: qsTr("Address"), width: 220 },
                    { title: qsTr("Client"), fill: true },
                    { title: qsTr("Progress"), width: 96, right: true },
                    { title: qsTr("Down"), width: 96, right: true },
                    { title: qsTr("Up"), width: 96, right: true }
                ]
                delegate: DetailRow {
                    id: peerRow
                    required property var modelData
                    DetailCell { Layout.preferredWidth: 220; text: (peerRow.modelData.country ? peerRow.modelData.country + "  " : "") + peerRow.modelData.address; font.family: Theme.fontMono; font.pixelSize: Theme.textXs }
                    DetailCell { Layout.fillWidth: true; Layout.leftMargin: 16; text: peerRow.modelData.client || "—" }
                    DetailCell { Layout.preferredWidth: 96; alignRight: true; text: Math.floor(peerRow.modelData.progress * 1000) / 10 + "%" }
                    DetailCell { Layout.preferredWidth: 96; alignRight: true; text: Format.speed(peerRow.modelData.dlSpeed); dim: peerRow.modelData.dlSpeed === 0 }
                    DetailCell { Layout.preferredWidth: 96; alignRight: true; text: Format.speed(peerRow.modelData.upSpeed); dim: peerRow.modelData.upSpeed === 0 }
                }
            }
        }
    }

    function priorityLabel(p) {
        switch (p) {
        case 0: return qsTr("Skip")
        case 6: return qsTr("High")
        case 7: return qsTr("Maximum")
        default: return qsTr("Normal")
        }
    }
    function trackerLabel(s) {
        switch (s) {
        case "working": return qsTr("Working")
        case "notWorking": return qsTr("Not working")
        case "error": return qsTr("Tracker error")
        case "unreachable": return qsTr("Unreachable")
        default: return qsTr("Not contacted")
        }
    }
    function trackerColor(s) {
        switch (s) {
        case "working": return Theme.upload
        case "notContacted": return Theme.textFaint
        default: return Theme.error
        }
    }

    UiMenu {
        id: priorityMenu
        property int fileIndex: -1
        implicitWidth: 180
        UiMenuItem { text: qsTr("Skip"); onTriggered: details.setFilePriority(priorityMenu.fileIndex, 0) }
        UiMenuItem { text: qsTr("Normal"); onTriggered: details.setFilePriority(priorityMenu.fileIndex, 1) }
        UiMenuItem { text: qsTr("High"); onTriggered: details.setFilePriority(priorityMenu.fileIndex, 6) }
        UiMenuItem { text: qsTr("Maximum"); onTriggered: details.setFilePriority(priorityMenu.fileIndex, 7) }
    }

    // --- Pieces ---------------------------------------------------------------------------------
    component Fact: ColumnLayout {
        property string label
        property string value
        property bool mono: false
        property color valueColor: Theme.text
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 2
        Text {
            text: parent.label
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
        }
        Text {
            Layout.fillWidth: true
            text: parent.value
            color: parent.valueColor
            font.family: parent.mono ? Theme.fontMono : Theme.fontText
            font.pixelSize: parent.mono ? Theme.textXs : Theme.textSm
            font.features: { "tnum": 1 }
            elide: Text.ElideMiddle
        }
    }

    component DetailCell: Text {
        property bool alignRight: false
        property bool dim: false
        Layout.fillHeight: true
        color: dim ? Theme.textFaint : Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.textSm
        font.features: { "tnum": 1 }
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    component DetailRow: Item {
        default property alias cells: cellRow.data
        width: ListView.view ? ListView.view.width : 0
        height: 36
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
        RowLayout {
            id: cellRow
            anchors.fill: parent
            anchors.leftMargin: Theme.sp(6)
            anchors.rightMargin: Theme.sp(6)
            spacing: 0
        }
    }

    // A list with a small header row and an empty state
    component DetailList: Item {
        id: dl
        property alias model: lv.model
        property alias delegate: lv.delegate
        property var columns: []
        property string emptyText

        RowLayout {
            id: head
            x: Theme.sp(6)
            width: parent.width - 2 * Theme.sp(6)
            height: 32
            spacing: 0
            Repeater {
                model: dl.columns
                Text {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: modelData.fill === true
                    Layout.preferredWidth: modelData.width ?? 0
                    Layout.leftMargin: index > 0 && !modelData.right ? 16 : 0
                    text: modelData.title
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    font.weight: Font.Medium
                    horizontalAlignment: modelData.right ? Text.AlignRight : Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillHeight: true
                }
            }
        }
        Rectangle {
            y: head.height
            width: parent.width
            height: 1
            color: Theme.border
        }
        ListView {
            id: lv
            anchors.fill: parent
            anchors.topMargin: head.height + 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
        }
        Text {
            visible: lv.count === 0
            anchors.centerIn: lv
            text: dl.emptyText
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
        }
    }
}
