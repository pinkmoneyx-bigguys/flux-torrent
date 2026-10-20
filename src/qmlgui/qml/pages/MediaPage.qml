import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Media library: the video files of all torrents as a grid of cards (or a table), by kind — movies,
// series, still downloading — with search and sorting. A card opens a side sheet with the file's details;
// a finished file plays in the default player until the built-in player arrives.
Surface {
    id: page
    objectName: "page_media"

    property string title: qsTr("Media library")
    property string hint: qsTr("Movies and episodes from your torrents.")

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

    property string view: "grid"
    // The built-in player exists (Flux was built with libmpv)
    property bool playerAvailable: true
    // Play a library item; startAt < 0 continues from the saved position
    signal playRequested(string key, real startAt)

    // A stable hue per title, for the generated cover
    function hue(text) {
        let h = 0
        for (let i = 0; i < text.length; ++i)
            h = (h * 31 + text.charCodeAt(i)) % 360
        return h / 360
    }
    function episodeLabel(season, episode) {
        if (season <= 0 && episode <= 0)
            return ""
        const pad = n => (n < 10 ? "0" : "") + n
        return season > 0 ? "S" + pad(season) + "E" + pad(episode) : qsTr("Ep. %1").arg(episode)
    }
    function qualityLabel(q) {
        return q === "2160p" ? "4K" : q
    }
    function meta(item) {
        const parts = []
        if (item.season > 0 || item.episode > 0)
            parts.push(episodeLabel(item.season, item.episode))
        if (item.year > 0)
            parts.push(item.year)
        parts.push(Format.size(item.size))
        return parts.join("  ·  ")
    }
    function clock(seconds) {
        const s = Math.floor(seconds % 60)
        const m = Math.floor(seconds / 60) % 60
        const h = Math.floor(seconds / 3600)
        const pad = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    }
    function open(key) {
        sheet.key = key
        sheet.open()
    }
    function play(key) {
        const item = MediaLibraryModel.get(key)
        if (playerAvailable || item.complete)
            playRequested(key, -1)
        else
            open(key)
    }
    function watchedOf(key) {
        return WatchHistory.revision >= 0 ? WatchHistory.progress(key) : 0
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            title: page.title

            UiSelect {
                objectName: "mediaSort"
                Layout.preferredWidth: 220
                text: qsTr("Sort")
                iconPath: Icons.sort
                currentKey: MediaLibraryModel.sortKey
                model: [
                    { key: "added", label: qsTr("Recently added") },
                    { key: "title", label: qsTr("Title") },
                    { key: "size", label: qsTr("Size") }
                ]
                onActivated: key => MediaLibraryModel.sortKey = key
            }
            UiTabs {
                objectName: "mediaView"
                currentKey: page.view
                model: [{ key: "grid", label: qsTr("Grid") }, { key: "list", label: qsTr("List") }]
                onActivated: key => page.view = key
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            Layout.bottomMargin: Theme.sp(4)
            spacing: Theme.sp(3)

            UiTabs {
                objectName: "mediaKind"
                currentKey: MediaLibraryModel.kind
                model: [
                    { key: "all", label: qsTr("All"), count: MediaLibraryModel.counts.all },
                    { key: "movies", label: qsTr("Movies"), count: MediaLibraryModel.counts.movies },
                    { key: "series", label: qsTr("Series"), count: MediaLibraryModel.counts.series },
                    { key: "downloading", label: qsTr("Downloading"), count: MediaLibraryModel.counts.downloading }
                ]
                onActivated: key => MediaLibraryModel.kind = key
            }
            Item { Layout.fillWidth: true }
            UiInput {
                objectName: "mediaSearch"
                Layout.preferredWidth: 260
                iconPath: Icons.search
                placeholderText: qsTr("Search the library…")
                onTextChanged: MediaLibraryModel.search = text
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Grid ---------------------------------------------------------------------------
            GridView {
                id: grid
                objectName: "mediaGrid"
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(6) - 8
                anchors.rightMargin: Theme.sp(6) - 8
                visible: page.view === "grid" && count > 0
                model: MediaLibraryModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                bottomMargin: Theme.sp(6)
                readonly property int columns: Math.max(2, Math.floor(width / 250))
                cellWidth: Math.floor(width / columns)
                cellHeight: (cellWidth - 16) * 9 / 16 + 72
                ScrollBar.vertical: ScrollBar {}
                delegate: MediaCard {
                    width: grid.cellWidth
                    height: grid.cellHeight
                }
            }

            // --- List ---------------------------------------------------------------------------
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(6)
                anchors.rightMargin: Theme.sp(6)
                anchors.bottomMargin: Theme.sp(6)
                visible: page.view === "list" && MediaLibraryModel.count > 0
                radius: Theme.radiusCtl + 2
                color: "transparent"
                border.width: 1
                border.color: Theme.border
                clip: true

                ListView {
                    id: list
                    objectName: "mediaList"
                    anchors.fill: parent
                    anchors.margins: 1
                    model: MediaLibraryModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    headerPositioning: ListView.OverlayHeader
                    ScrollBar.vertical: ScrollBar {}
                    header: Rectangle {
                        width: list.width
                        height: 40
                        z: 2
                        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.04) : "#141414"
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 0
                            HeadText { text: qsTr("Title"); Layout.fillWidth: true }
                            HeadText { text: qsTr("Episode"); Layout.preferredWidth: 90 }
                            HeadText { text: qsTr("Quality"); Layout.preferredWidth: 90 }
                            HeadText { text: qsTr("Size"); Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                            HeadText { text: qsTr("Progress"); Layout.preferredWidth: 150; Layout.leftMargin: 24 }
                            Item { Layout.preferredWidth: 40 }
                        }
                    }
                    delegate: MediaRow {
                        width: list.width
                    }
                }
            }

            // --- Empty states -------------------------------------------------------------------
            ColumnLayout {
                objectName: "mediaEmpty"
                visible: MediaLibraryModel.count === 0
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -24
                width: Math.min(parent.width - 48, 420)
                spacing: Theme.sp(2)

                readonly property bool nothingAtAll: (MediaLibraryModel.counts.all ?? 0) === 0

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Theme.sp(2)
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Theme.radiusCtl
                    color: Theme.muted
                    Icon {
                        anchors.centerIn: parent
                        path: parent.parent.nothingAtAll ? Icons.film : Icons.filter
                        size: 20
                        strokeWidth: 1.75
                        color: Theme.text
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: parent.nothingAtAll ? qsTr("No videos yet") : qsTr("Nothing here")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: parent.nothingAtAll
                          ? qsTr("Movies and episodes from your torrents show up here as soon as a torrent with video starts downloading.")
                          : qsTr("No videos match this filter.")
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    lineHeight: 1.3
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }
                UiButton {
                    visible: parent.nothingAtAll
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.sp(3)
                    iconPath: Icons.search
                    text: qsTr("Search trackers")
                    onClicked: if (page.Window.window && page.Window.window.currentPage !== undefined) page.Window.window.currentPage = 1
                }
            }
        }
    }

    // --- Pieces ---------------------------------------------------------------------------------
    // The generated cover: a dark tint per title, the kind icon, quality and episode badges, progress
    component Cover: Rectangle {
        id: cover
        property string title
        property string quality
        property int season
        property int episode
        property real progress: 1
        // share already watched (WatchHistory)
        property real watched: 0
        property bool hot: false

        readonly property real h: page.hue(title)
        radius: Theme.radiusCtl + 2
        clip: true
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Qt.hsla(cover.h, 0.28, 0.20, 1) }
            GradientStop { position: 1; color: Qt.hsla((cover.h + 0.06) % 1, 0.30, 0.09, 1) }
        }
        border.width: 1
        border.color: cover.hot ? Theme.alpha(Theme.text, 0.25) : Theme.border

        Icon {
            anchors.centerIn: parent
            visible: !cover.hot
            path: cover.season > 0 || cover.episode > 0 ? Icons.media : Icons.film
            size: Math.min(36, cover.height * 0.28)
            strokeWidth: 1.25
            color: Qt.rgba(1, 1, 1, 0.28)
        }
        // play affordance on hover
        Rectangle {
            visible: cover.hot
            anchors.centerIn: parent
            width: 44
            height: 44
            radius: 22
            color: cover.progress >= 1 ? "#FAFAFA" : Qt.rgba(1, 1, 1, 0.16)
            Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                path: Icons.play
                size: 18
                strokeWidth: 2
                color: cover.progress >= 1 ? "#0A0A0A" : "#FAFAFA"
            }
        }
        Row {
            x: 8
            y: 8
            spacing: 6
            CoverBadge { visible: cover.quality !== ""; text: page.qualityLabel(cover.quality) }
            CoverBadge { visible: cover.season > 0 || cover.episode > 0; text: page.episodeLabel(cover.season, cover.episode) }
        }
        // watched part, above the download edge
        Rectangle {
            visible: cover.watched > 0.01
            anchors.bottom: parent.bottom
            anchors.bottomMargin: cover.progress < 1 ? 4 : 0
            width: parent.width * cover.watched
            height: 3
            color: "#FAFAFA"
        }
        // download progress along the bottom edge
        Rectangle {
            visible: cover.progress < 1
            anchors.bottom: parent.bottom
            width: parent.width
            height: 4
            color: Qt.rgba(0, 0, 0, 0.45)
            Rectangle {
                width: parent.width * cover.progress
                height: parent.height
                color: Theme.download
            }
        }
    }

    component CoverBadge: Rectangle {
        property alias text: label.text
        implicitWidth: label.implicitWidth + 12
        implicitHeight: 20
        radius: 5
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
            id: label
            anchors.centerIn: parent
            color: "#FAFAFA"
            font.family: Theme.fontText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    component MediaCard: Item {
        id: card
        required property string key
        required property string title
        required property string quality
        required property int season
        required property int episode
        required property int year
        required property real size
        required property real progress

        Accessible.role: Accessible.Button
        Accessible.name: title

        HoverHandler { id: hover }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Cover {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                title: card.title
                quality: card.quality
                season: card.season
                episode: card.episode
                progress: card.progress
                watched: page.watchedOf(card.key)
                hot: hover.hovered

                TapHandler {
                    onTapped: page.play(card.key)
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: card.progress < 1
                          ? qsTr("%1% · downloading").arg(Math.floor(card.progress * 100))
                          : page.meta(card)
                    color: card.progress < 1 ? Theme.download : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }
            }
        }
        // the text block opens the details
        TapHandler {
            onTapped: eventPoint => {
                if (eventPoint.position.y > card.height - 64)
                    page.open(card.key)
            }
        }
        // right click anywhere: details
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: page.open(card.key)
        }
    }

    component HeadText: Text {
        Layout.fillHeight: true
        color: Theme.textDim
        font.family: Theme.fontText
        font.pixelSize: Theme.textSm
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }

    component MediaRow: Rectangle {
        id: mr
        required property string key
        required property string title
        required property string quality
        required property int season
        required property int episode
        required property real size
        required property real progress

        height: 44
        color: rowHover.hovered ? Theme.alpha(Theme.muted, 0.5) : "transparent"
        HoverHandler { id: rowHover }
        TapHandler { onTapped: page.open(mr.key) }
        TapHandler { onDoubleTapped: page.play(mr.key) }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(3)
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 24
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.hsla(page.hue(mr.title), 0.28, 0.22, 1) }
                        GradientStop { position: 1; color: Qt.hsla(page.hue(mr.title), 0.30, 0.10, 1) }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: mr.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
            Text {
                Layout.preferredWidth: 90
                text: page.episodeLabel(mr.season, mr.episode) || "—"
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.features: { "tnum": 1 }
            }
            Item {
                Layout.preferredWidth: 90
                Layout.fillHeight: true
                UiBadge {
                    visible: mr.quality !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.qualityLabel(mr.quality)
                }
            }
            Text {
                Layout.preferredWidth: 90
                horizontalAlignment: Text.AlignRight
                text: Format.size(mr.size)
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.features: { "tnum": 1 }
            }
            RowLayout {
                Layout.preferredWidth: 150
                Layout.maximumWidth: 150
                Layout.leftMargin: 24
                spacing: Theme.sp(2)
                UiProgress {
                    Layout.preferredWidth: 90
                    value: mr.progress
                    color: mr.progress >= 1 ? Theme.upload : Theme.download
                }
                Text {
                    text: Math.floor(mr.progress * 100) + "%"
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                }
            }
            Item {
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                UiButton {
                    anchors.centerIn: parent
                    size: "iconSm"
                    variant: "ghost"
                    iconPath: Icons.play
                    enabled: mr.progress >= 1
                    Accessible.name: qsTr("Play %1").arg(mr.title)
                    onClicked: page.play(mr.key)
                }
            }
        }
    }

    // --- Details sheet ----------------------------------------------------------------------------
    // shadcn Sheet: slides in from the right over a dimmed page
    Drawer {
        id: sheet
        objectName: "mediaSheet"
        property string key
        readonly property var item: key !== "" && sheet.visible ? MediaLibraryModel.get(key) : ({})

        edge: Qt.RightEdge
        width: Math.min(440, page.width * 0.5)
        height: page.Window.window ? page.Window.window.height : page.height
        dim: true
        interactive: visible

        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

        background: Rectangle {
            color: Theme.glass ? "#17151F" : Theme.background
            Rectangle { width: 1; height: parent.height; color: Theme.border }
        }

        contentItem: Flickable {
            clip: true
            contentHeight: sheetColumn.implicitHeight + 48
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: sheetColumn
                x: 24
                y: 24
                width: parent.width - 48
                spacing: Theme.sp(4)

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        objectName: "mediaSheetTitle"
                        Layout.fillWidth: true
                        text: sheet.item.title ?? ""
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        wrapMode: Text.Wrap
                    }
                    UiButton {
                        Layout.alignment: Qt.AlignTop
                        size: "iconSm"
                        variant: "ghost"
                        iconPath: Icons.x
                        Accessible.name: qsTr("Close")
                        onClicked: sheet.close()
                    }
                }
                Cover {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 9 / 16
                    title: sheet.item.title ?? ""
                    quality: sheet.item.quality ?? ""
                    season: sheet.item.season ?? 0
                    episode: sheet.item.episode ?? 0
                    progress: sheet.item.progress ?? 1
                }

                // Actions
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp(2)
                    readonly property real resumeAt: WatchHistory.revision >= 0 ? WatchHistory.resumePosition(sheet.key) : 0
                    UiButton {
                        objectName: "mediaPlay"
                        Layout.fillWidth: true
                        size: "default"
                        iconPath: Icons.play
                        text: parent.resumeAt > 0 ? qsTr("Continue from %1").arg(page.clock(parent.resumeAt))
                            : sheet.item.complete === true ? qsTr("Play") : qsTr("Watch while downloading")
                        enabled: sheet.item.complete === true || page.playerAvailable
                        onClicked: {
                            sheet.close()
                            page.playRequested(sheet.key, -1)
                        }
                    }
                    UiButton {
                        objectName: "mediaPlayFromStart"
                        visible: parent.resumeAt > 0
                        Layout.fillWidth: true
                        variant: "outline"
                        text: qsTr("Play from the start")
                        onClicked: {
                            sheet.close()
                            page.playRequested(sheet.key, 0)
                        }
                    }
                    Text {
                        visible: sheet.item.complete !== true && !page.playerAvailable
                        Layout.fillWidth: true
                        text: qsTr("The file is still downloading. Watching while it downloads needs the built-in player.")
                        color: Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textXs
                        wrapMode: Text.Wrap
                    }
                    UiButton {
                        Layout.fillWidth: true
                        variant: "outline"
                        iconPath: Icons.folder
                        text: qsTr("Show in folder")
                        onClicked: MediaLibraryModel.showInFolder(sheet.key)
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.sp(4)
                    rowSpacing: Theme.sp(3)

                    SheetFact { label: qsTr("Size"); value: Format.size(sheet.item.size ?? 0) }
                    SheetFact { label: qsTr("Downloaded"); value: Math.floor((sheet.item.progress ?? 0) * 1000) / 10 + "%" }
                    SheetFact { label: qsTr("Quality"); value: page.qualityLabel(sheet.item.quality ?? "") || "—" }
                    SheetFact {
                        label: (sheet.item.season ?? 0) > 0 || (sheet.item.episode ?? 0) > 0 ? qsTr("Episode") : qsTr("Year")
                        value: (sheet.item.season ?? 0) > 0 || (sheet.item.episode ?? 0) > 0
                               ? page.episodeLabel(sheet.item.season, sheet.item.episode)
                               : ((sheet.item.year ?? 0) > 0 ? String(sheet.item.year) : "—")
                    }
                    SheetFact { Layout.columnSpan: 2; label: qsTr("File"); value: sheet.item.fileName ?? ""; mono: true }
                    SheetFact { Layout.columnSpan: 2; label: qsTr("Torrent"); value: sheet.item.torrentName ?? "" }
                    SheetFact { Layout.columnSpan: 2; label: qsTr("Location"); value: sheet.item.path ?? ""; mono: true }
                }
            }
        }
    }

    component SheetFact: ColumnLayout {
        property string label
        property string value
        property bool mono: false
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
            color: Theme.text
            font.family: parent.mono ? Theme.fontMono : Theme.fontText
            font.pixelSize: parent.mono ? Theme.textXs : Theme.textSm
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }
}
