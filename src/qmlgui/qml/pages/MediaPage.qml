import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Media library: the videos of all torrents as a shelf of posters, one per film or series (its episodes
// together), or as a table of files; by kind — movies, series, still downloading — with search and sorting.
// A film's poster plays it; a series opens its episodes; the details slide in from the right.
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

    // A stable hue per title, for the list's little covers
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
    // "S1", "S1–3"
    function seasonsLabel(seasons) {
        if (!seasons || seasons.length === 0)
            return ""
        return seasons.length === 1 ? "S" + seasons[0] : "S" + seasons[0] + "–" + seasons[seasons.length - 1]
    }
    // what a title is, under its name
    function titleMeta(t) {
        if (t.downloading)
            return qsTr("%1% · downloading").arg(Math.floor(t.progress * 100))
        const parts = []
        if (t.series)
            parts.push(qsTr("%n episode(s)", "", t.count))
        else if (t.year > 0)
            parts.push(String(t.year))
        parts.push(Format.size(t.size))
        return parts.join("  ·  ")
    }
    function clock(seconds) {
        const s = Math.floor(seconds % 60)
        const m = Math.floor(seconds / 60) % 60
        const h = Math.floor(seconds / 3600)
        const pad = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    }
    // the details of one file
    function open(key) {
        sheet.group = null
        sheet.key = key
        sheet.open()
    }
    // a film or a series: its details, its episodes
    function openTitle(t) {
        sheet.group = t
        sheet.key = t.main
        sheet.open()
    }
    function play(key) {
        const item = MediaLibraryModel.get(key)
        if (playerAvailable || item.complete)
            playRequested(key, -1)
        else
            open(key)
    }
    // a poster's click: a film plays, a series shows its episodes
    function activate(t) {
        if (t.series || t.count > 1)
            openTitle(t)
        else
            play(t.main)
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
            Layout.bottomMargin: Theme.sp(2)
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
                Layout.fillWidth: true
                Layout.maximumWidth: 280
                Layout.minimumWidth: 160
                iconPath: Icons.search
                placeholderText: qsTr("Search the library…")
                onTextChanged: MediaLibraryModel.search = text
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Shelf of posters -----------------------------------------------------------------
            GridView {
                id: grid
                objectName: "mediaGrid"
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(5)
                anchors.rightMargin: Theme.sp(3)
                visible: page.view === "grid" && count > 0
                model: MediaLibraryModel.titles
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                topMargin: Theme.sp(2)
                bottomMargin: Theme.sp(6)
                readonly property int columns: Math.max(2, Math.floor(width / 190))
                cellWidth: Math.floor(width / columns)
                cellHeight: Math.round((cellWidth - 2 * Theme.sp(2)) * 1.5) + 76
                cacheBuffer: Math.max(0, cellHeight * 2)
                reuseItems: true
                ScrollBar.vertical: ScrollBar {}
                SmoothWheel { step: 280 }
                delegate: TitleCard {
                    width: grid.cellWidth
                    height: grid.cellHeight
                }
            }

            // --- Files ----------------------------------------------------------------------------
            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(6)
                anchors.rightMargin: Theme.sp(6)
                anchors.topMargin: Theme.sp(2)
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
                    reuseItems: true
                    ScrollBar.vertical: ScrollBar {}
                    SmoothWheel {}
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
    component CoverBadge: Rectangle {
        property alias text: label.text
        implicitWidth: label.implicitWidth + 12
        implicitHeight: 20
        radius: 5
        color: Qt.rgba(0, 0, 0, 0.62)
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

    // A film or a series on the shelf: its poster (what is on offer on it, how far it has come along the
    // bottom), its name and what it is
    component TitleCard: Item {
        id: card
        required property var modelData
        readonly property bool hot: hover.hovered
        // a film: how much of it was watched
        readonly property real watched: !modelData.series && modelData.count === 1 ? page.watchedOf(modelData.main) : 0

        Accessible.role: Accessible.Button
        Accessible.name: modelData.title

        HoverHandler { id: hover }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sp(2)
            anchors.bottomMargin: Theme.sp(4)
            spacing: Theme.sp(2)

            FilmPoster {
                id: cover
                Layout.fillWidth: true
                Layout.preferredHeight: width * 1.5
                radius: 8
                film: ({ key: card.modelData.posterKey, title: card.modelData.title, original: card.modelData.original,
                         year: card.modelData.year, series: card.modelData.series })
                border.width: 1
                border.color: card.hot ? Theme.alpha(Theme.text, 0.3) : Theme.border
                scale: card.hot && !Theme.reducedMotion ? 1.02 : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
                }

                TapHandler { onTapped: page.activate(card.modelData) }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: page.openTitle(card.modelData)
                }

                // what is on offer, top left; a series' seasons and episodes, top right
                Row {
                    x: 6
                    y: 6
                    spacing: 4
                    CoverBadge {
                        visible: card.modelData.quality !== ""
                        text: page.qualityLabel(card.modelData.quality)
                    }
                }
                CoverBadge {
                    visible: card.modelData.series
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    text: [page.seasonsLabel(card.modelData.seasons), qsTr("%n ep.", "", card.modelData.count)]
                          .filter(t => t !== "").join(" · ")
                }

                // play (a film) or the episodes (a series), under the pointer
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    opacity: card.hot ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: Theme.durFast }
                    }
                    gradient: Gradient {
                        GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0) }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        radius: 24
                        color: Qt.rgba(1, 1, 1, 0.92)
                        Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: card.modelData.series ? 0 : 1
                            path: card.modelData.series || card.modelData.count > 1 ? Icons.list : Icons.play
                            size: 18
                            strokeWidth: 2.2
                            color: "#0A0A0A"
                        }
                    }
                }

                // watched (a film), and the download along the bottom edge
                Rectangle {
                    visible: card.watched > 0.01
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: card.modelData.downloading ? 4 : 0
                    x: 1
                    width: (parent.width - 2) * card.watched
                    height: 3
                    color: "#FAFAFA"
                }
                Rectangle {
                    visible: card.modelData.downloading
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    x: 1
                    width: parent.width - 2
                    height: 4
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Rectangle {
                        width: parent.width * card.modelData.progress
                        height: parent.height
                        color: Theme.download
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.modelData.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: page.titleMeta(card.modelData)
                    color: card.modelData.downloading ? Theme.download : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }
                // the name opens the details
                TapHandler { onTapped: page.openTitle(card.modelData) }
            }
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

        height: 48
        color: rowHover.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durFast }
        }
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
                    implicitWidth: 24
                    implicitHeight: 32
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.hsla(page.hue(mr.title), 0.28, 0.24, 1) }
                        GradientStop { position: 1; color: Qt.hsla(page.hue(mr.title), 0.30, 0.11, 1) }
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
                    enabled: mr.progress >= 1 || page.playerAvailable
                    Accessible.name: qsTr("Play %1").arg(mr.title)
                    onClicked: page.play(mr.key)
                }
            }
        }
    }

    // --- Details sheet ----------------------------------------------------------------------------
    // shadcn Sheet: slides in from the right over a dimmed page. A film (or one file): its poster, how to
    // play it and what it is; a series: its episodes by season.
    Drawer {
        id: sheet
        objectName: "mediaSheet"
        // the file whose details show (a film's main one)
        property string key
        // the film or series it was opened for, or null (a file of the table)
        property var group: null
        readonly property var item: key !== "" && sheet.visible ? MediaLibraryModel.get(key) : ({})
        readonly property bool episodes: group !== null && (group.series || group.count > 1)
        readonly property var film: group !== null
            ? { key: group.posterKey, title: group.title, original: group.original, year: group.year, series: group.series }
            : Posters.film(item.torrentName || item.fileName || "")

        edge: Qt.RightEdge
        width: Math.min(480, page.width * 0.55)
        height: page.Window.window ? page.Window.window.height : page.height
        dim: true
        interactive: visible

        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

        background: Rectangle {
            color: Theme.glass ? "#17151F" : Theme.background
            Rectangle { width: 1; height: parent.height; color: Theme.border }
        }

        contentItem: Flickable {
            id: sheetFlick
            clip: true
            contentHeight: sheetColumn.implicitHeight + 56
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            SmoothWheel { step: 200 }

            ColumnLayout {
                id: sheetColumn
                x: 28
                y: 28
                width: parent.width - 56
                spacing: Theme.sp(5)

                // poster, name, what it is
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp(4)
                    FilmPoster {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: 104
                        Layout.preferredHeight: 156
                        radius: 8
                        film: sheet.film
                        border.width: 1
                        border.color: Theme.border
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.sp(2)
                        Text {
                            objectName: "mediaSheetTitle"
                            Layout.fillWidth: true
                            text: sheet.group !== null ? sheet.group.title : (sheet.item.title ?? "")
                            color: Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: sheet.group !== null
                                  ? [sheet.group.original !== sheet.group.title ? sheet.group.original : "",
                                     sheet.group.year > 0 ? String(sheet.group.year) : ""].filter(t => t !== "").join(" · ")
                                  : ""
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                            wrapMode: Text.Wrap
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            UiBadge {
                                readonly property string q: sheet.group !== null ? sheet.group.quality : (sheet.item.quality ?? "")
                                visible: q !== ""
                                text: page.qualityLabel(q)
                            }
                            UiBadge {
                                visible: sheet.episodes
                                text: sheet.group !== null ? qsTr("%n episode(s)", "", sheet.group.count) : ""
                            }
                            UiBadge {
                                text: Format.size(sheet.group !== null ? sheet.group.size : (sheet.item.size ?? 0))
                            }
                        }
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

                // --- One film: play it ------------------------------------------------------------
                ColumnLayout {
                    visible: !sheet.episodes
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

                // --- A series: its episodes by season ---------------------------------------------
                ColumnLayout {
                    objectName: "mediaEpisodes"
                    visible: sheet.episodes
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: sheet.episodes ? sheet.group.items : []
                        delegate: ColumnLayout {
                            id: ep
                            required property var modelData
                            required property int index
                            readonly property var previous: index > 0 ? sheet.group.items[index - 1] : null
                            readonly property real watched: page.watchedOf(modelData.key)
                            Layout.fillWidth: true
                            spacing: 0

                            // a season's heading, before its first episode
                            Text {
                                visible: ep.modelData.season > 0 && (ep.previous === null || ep.previous.season !== ep.modelData.season)
                                Layout.topMargin: ep.index > 0 ? Theme.sp(4) : 0
                                Layout.bottomMargin: Theme.sp(2)
                                text: qsTr("Season %1").arg(ep.modelData.season)
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textXs
                                font.weight: Font.Medium
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.6
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 52
                                radius: Theme.radiusCtl
                                color: epHover.hovered ? Theme.hover : "transparent"
                                HoverHandler { id: epHover }
                                TapHandler { onTapped: page.play(ep.modelData.key) }
                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: page.open(ep.modelData.key)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: Theme.sp(3)

                                    // watched all through, partly, or not yet
                                    Rectangle {
                                        implicitWidth: 28
                                        implicitHeight: 28
                                        radius: 14
                                        color: ep.watched >= 0.9 ? Theme.alpha(Theme.upload, 0.16) : Theme.muted
                                        Icon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: ep.watched >= 0.9 ? 0 : 1
                                            path: ep.watched >= 0.9 ? Icons.check : Icons.play
                                            size: 13
                                            strokeWidth: 2.2
                                            color: ep.watched >= 0.9 ? Theme.upload : Theme.text
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Text {
                                            Layout.fillWidth: true
                                            text: ep.modelData.episode > 0 ? qsTr("Episode %1").arg(ep.modelData.episode) : ep.modelData.fileName
                                            color: Theme.text
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.textSm
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: [page.episodeLabel(ep.modelData.season, ep.modelData.episode),
                                                   page.qualityLabel(ep.modelData.quality), Format.size(ep.modelData.size),
                                                   ep.modelData.complete ? "" : qsTr("%1% downloaded").arg(Math.floor(ep.modelData.progress * 100))]
                                                  .filter(t => t !== "").join("  ·  ")
                                            color: ep.modelData.complete ? Theme.textDim : Theme.download
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.textXs
                                            font.features: { "tnum": 1 }
                                            elide: Text.ElideRight
                                        }
                                        // how far it was watched
                                        Rectangle {
                                            visible: ep.watched > 0.01 && ep.watched < 0.9
                                            Layout.fillWidth: true
                                            Layout.topMargin: 2
                                            implicitHeight: 3
                                            radius: 1.5
                                            color: Theme.muted
                                            Rectangle {
                                                width: parent.width * ep.watched
                                                height: parent.height
                                                radius: 1.5
                                                color: Theme.text
                                            }
                                        }
                                    }
                                    UiButton {
                                        size: "iconSm"
                                        variant: "ghost"
                                        iconPath: Icons.info
                                        Accessible.name: qsTr("Details")
                                        onClicked: page.open(ep.modelData.key)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border; visible: !sheet.episodes }

                GridLayout {
                    visible: !sheet.episodes
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
