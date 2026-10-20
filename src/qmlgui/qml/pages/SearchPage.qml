import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Effects
import QtQuick.Layouts
import Flux

// Tracker search. The header holds the query; a slim bar under it the category, the source, the
// filters, the result count and the view switch. Results show as a table (each release with a small
// poster and the film it is) or as cards, one per film with its poster, that open the film's releases.
// Posters come from Posters (IMDb title suggestions). Python is needed only for plugins: JacRed works as is.
Surface {
    id: page
    objectName: "page_search"

    property string title: qsTr("Tracker search")
    property string hint: qsTr("Search torrents on all your trackers at once.")

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

    readonly property bool running: SearchEngine.status === "running"
    // JacRed (built in) needs no Python: searching is possible as soon as there is a source
    readonly property bool ready: SearchEngine.plugins.length > 0
    readonly property bool hasResults: page.ready && SearchEngine.status !== "idle"
    property string category: "all"
    property string plugin: "enabled"
    // "list" or "cards"; remembered
    property string view: UiSettings.layoutValue("searchView", "list")
    function setView(v) {
        view = v
        UiSettings.setLayoutValue("searchView", v)
    }
    // cards in a row: 0 picks by the width; remembered
    property int gridColumns: UiSettings.layoutValue("searchColumns", 0)
    function setGridColumns(n) {
        gridColumns = n
        UiSettings.setLayoutValue("searchColumns", n)
    }

    // "Watch without downloading" on a result (a magnet link)
    signal watchRequested(string source)

    function categoryLabel(key) {
        switch (key) {
        case "all": return qsTr("All categories")
        case "anime": return qsTr("Anime")
        case "books": return qsTr("Books")
        case "games": return qsTr("Games")
        case "movies": return qsTr("Movies")
        case "music": return qsTr("Music")
        case "pictures": return qsTr("Pictures")
        case "software": return qsTr("Software")
        case "tv": return qsTr("TV shows")
        default: return key
        }
    }

    // From the command palette: fill the query and search right away when possible
    function searchFor(text) {
        queryInput.text = text
        if (ready)
            search()
    }

    function search() {
        if (queryInput.text.trim() === "")
            return
        SearchEngine.start(queryInput.text, category, plugin)
    }

    function sortBy(key) {
        const natural = key !== "name" && key !== "engine"
        if (resultsFilter.sortKey !== key) {
            resultsFilter.sortKey = key
            resultsFilter.descending = natural
        } else if (resultsFilter.descending === natural) {
            resultsFilter.descending = !natural
        } else {
            resultsFilter.sortKey = ""
            resultsFilter.descending = false
        }
    }

    function trackerName(engine) {
        for (const p of SearchEngine.plugins) {
            if (p.name === engine)
                return p.fullName
        }
        return engine
    }

    // "Interstellar · 2014 · 1080p": what a release is, under its name
    function filmLine(film) {
        const parts = []
        if (film.original !== "" && film.original !== film.title)
            parts.push(film.original)
        if (film.year > 0)
            parts.push(String(film.year))
        if (film.quality !== "")
            parts.push(film.quality === "2160p" ? "4K" : film.quality)
        return parts.join(" · ")
    }

    SearchResultsFilter {
        id: resultsFilter
        objectName: "searchResultsFilter"
        sourceModel: SearchEngine.results
        sortKey: "seeds"
        descending: true
        seededOnly: seededSwitch.checked
        postersOnly: postersSwitch.checked
    }

    Connections {
        target: SearchEngine
        function onMessage(text, isError) {
            toast.show(text, isError)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // --- Query ------------------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            implicitHeight: 56

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(6)
                anchors.rightMargin: Theme.sp(4)
                spacing: Theme.sp(3)

                Text {
                    text: page.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
                UiInput {
                    id: queryInput
                    objectName: "searchQuery"
                    Layout.fillWidth: true
                    Layout.maximumWidth: 640
                    Layout.leftMargin: Theme.sp(2)
                    implicitHeight: 36
                    enabled: page.ready
                    iconPath: Icons.search
                    placeholderText: qsTr("Film, series, game, anything…")
                    onAccepted: page.search()
                    // the last query stays in the field when coming back to the page
                    Component.onCompleted: text = SearchEngine.pattern
                }
                UiButton {
                    objectName: "searchButton"
                    size: "default"
                    variant: page.running ? "outline" : "default"
                    iconPath: page.running ? Icons.x : Icons.search
                    text: page.running ? qsTr("Stop") : qsTr("Search")
                    enabled: page.ready && (page.running || queryInput.text.trim() !== "")
                    onClicked: page.running ? SearchEngine.stop() : page.search()
                }
                Item { Layout.fillWidth: true }
                UiButton {
                    objectName: "pluginsButton"
                    variant: "ghost"
                    iconPath: Icons.puzzle
                    text: SearchEngine.plugins.length > 0
                          ? qsTr("Sources · %1").arg(SearchEngine.enabledPluginCount)
                          : qsTr("Sources")
                    enabled: SearchEngine.pythonAvailable || SearchEngine.plugins.length > 0
                    onClicked: pluginsDialog.open()
                }
            }
        }

        // --- Options and results bar --------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 44
            color: Theme.glass ? Qt.rgba(1, 1, 1, 0.03) : "#111111"
            visible: page.ready

            Rectangle { width: parent.width; height: 1; color: Theme.border }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(6)
                anchors.rightMargin: Theme.sp(4)
                spacing: Theme.sp(2)

                UiSelect {
                    objectName: "searchCategory"
                    implicitHeight: 30
                    Layout.preferredWidth: 160
                    text: qsTr("Category")
                    currentKey: page.category
                    model: SearchEngine.categories.map(c => ({ key: c.key, label: page.categoryLabel(c.key) }))
                    onActivated: key => page.category = key
                }
                UiSelect {
                    objectName: "searchPlugin"
                    implicitHeight: 30
                    Layout.preferredWidth: 190
                    text: qsTr("Sources")
                    currentKey: page.plugin
                    model: [{ key: "enabled", label: qsTr("All enabled sources") }]
                           .concat(SearchEngine.plugins.filter(p => p.enabled).map(p => ({ key: p.name, label: p.fullName })))
                    onActivated: key => page.plugin = key
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Theme.sp(1)
                    Layout.rightMargin: Theme.sp(1)
                    implicitWidth: 1
                    implicitHeight: 18
                    color: Theme.border
                }
                UiSpinner {
                    visible: page.running
                }
                Text {
                    objectName: "searchStatus"
                    Layout.fillWidth: true
                    text: {
                        const n = SearchEngine.results.count
                        switch (SearchEngine.status) {
                        case "idle": return ""
                        case "running": return qsTr("Searching for “%1”… %n result(s) so far", "", n).arg(SearchEngine.pattern)
                        case "failed": return SearchEngine.error
                        case "cancelled": return qsTr("Stopped. %n result(s) for “%1”", "", n).arg(SearchEngine.pattern)
                        default: return page.view === "cards" && resultsFilter.groups.length > 0
                                 ? qsTr("%n film(s), %1 release(s) for “%2”", "", resultsFilter.groups.length).arg(n).arg(SearchEngine.pattern)
                                 : qsTr("%n result(s) for “%1”", "", n).arg(SearchEngine.pattern)
                        }
                    }
                    color: SearchEngine.status === "failed" ? Theme.error : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    elide: Text.ElideRight
                }
                LabeledSwitch {
                    id: seededSwitch
                    objectName: "searchSeededOnly"
                    visible: page.hasResults
                    text: qsTr("With seeds")
                }
                LabeledSwitch {
                    id: postersSwitch
                    objectName: "searchPostersOnly"
                    visible: page.hasResults
                    Layout.leftMargin: Theme.sp(2)
                    text: qsTr("With posters")
                }
                // how many cards in a row
                UiSelect {
                    objectName: "searchColumns"
                    visible: page.view === "cards"
                    implicitHeight: 30
                    implicitWidth: 120
                    Layout.leftMargin: Theme.sp(2)
                    iconPath: Icons.grid
                    text: qsTr("Cards in a row")
                    currentKey: String(page.gridColumns)
                    model: [{ key: "0", label: qsTr("Auto") }].concat([3, 4, 5, 6, 7, 8].map(n => ({ key: String(n), label: qsTr("%n in a row", "", n) })))
                    onActivated: key => page.setGridColumns(Number(key))
                }
                // list / cards
                Row {
                    objectName: "searchViewSwitch"
                    spacing: 2
                    ViewButton { view: "list"; iconPath: Icons.list; text: qsTr("List") }
                    ViewButton { view: "cards"; iconPath: Icons.grid; text: qsTr("Cards") }
                }
            }
        }

        // --- Results --------------------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                objectName: "searchList"
                anchors.fill: parent
                visible: page.ready && resultsFilter.count > 0 && page.view === "list"
                model: resultsFilter
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                headerPositioning: ListView.OverlayHeader
                reuseItems: true
                ScrollBar.vertical: ScrollBar {}

                header: ResultsHeader {
                    width: list.width
                    z: 2
                }
                delegate: ResultRow {
                    width: list.width
                }
            }

            GridView {
                id: grid
                objectName: "searchGrid"
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(5)
                anchors.rightMargin: Theme.sp(3)
                anchors.topMargin: Theme.sp(4)
                visible: page.ready && resultsFilter.count > 0 && page.view === "cards"
                model: resultsFilter.groups
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                readonly property int columns: page.gridColumns > 0 ? page.gridColumns : Math.max(2, Math.floor(width / 190))
                cellWidth: Math.floor(width / columns)
                cellHeight: cellWidth * 1.5 + 78
                delegate: FilmCard {
                    width: grid.cellWidth
                    height: grid.cellHeight
                }
            }

            // Empty states, in order of what blocks the user first
            EmptyState {
                objectName: "searchNoPython"
                visible: !SearchEngine.pythonAvailable && SearchEngine.enabledPluginCount === 0
                iconPath: Icons.app
                title: qsTr("Python is required")
                text: qsTr("Tracker search runs plugins written in Python. Install Python 3.9 or newer for all users, then check again.")

                UiButton {
                    iconPath: Icons.externalLink
                    text: qsTr("Download Python")
                    onClicked: SearchEngine.openUrl("https://www.python.org/downloads/windows/")
                }
                UiButton {
                    variant: "outline"
                    iconPath: Icons.refresh
                    text: qsTr("Check again")
                    onClicked: SearchEngine.recheckPython()
                }
            }
            EmptyState {
                objectName: "searchNoPlugins"
                visible: SearchEngine.pythonAvailable && SearchEngine.plugins.length === 0
                iconPath: Icons.puzzle
                title: qsTr("No search plugins yet")
                text: qsTr("Plugins connect Flux to trackers. Install the official set, or add the plugins you trust.")

                UiButton {
                    iconPath: SearchEngine.busy ? "" : Icons.download
                    text: SearchEngine.busy ? qsTr("Installing…") : qsTr("Install official plugins")
                    enabled: !SearchEngine.busy
                    onClicked: SearchEngine.installOfficialPlugins()
                }
                UiButton {
                    variant: "outline"
                    text: qsTr("Manage plugins")
                    onClicked: pluginsDialog.open()
                }
            }
            EmptyState {
                objectName: "searchIdle"
                visible: page.ready && SearchEngine.status === "idle"
                iconPath: Icons.search
                title: qsTr("Search all your trackers at once")
                text: SearchEngine.enabledPluginCount > 0
                      ? qsTr("Type what you are looking for and press Enter. Results arrive as each of %n source(s) answers.", "", SearchEngine.enabledPluginCount)
                      : qsTr("All sources are turned off. Turn some on in Sources.")
            }
            EmptyState {
                objectName: "searchNothing"
                visible: page.ready && SearchEngine.status !== "idle" && !page.running && resultsFilter.count === 0
                iconPath: SearchEngine.status === "failed" ? Icons.x : Icons.filter
                title: SearchEngine.results.count > 0 ? qsTr("No results with these options")
                     : SearchEngine.status === "failed" ? qsTr("The search failed") : qsTr("Nothing found")
                text: SearchEngine.results.count > 0 ? qsTr("Turn the switches off to see all %n result(s).", "", SearchEngine.results.count)
                    : SearchEngine.status === "failed" ? SearchEngine.error
                    : qsTr("Try other words, another category or more plugins.")

                UiButton {
                    visible: SearchEngine.results.count > 0
                    variant: "outline"
                    text: qsTr("Show all")
                    onClicked: {
                        seededSwitch.checked = false
                        postersSwitch.checked = false
                    }
                }
            }
            ColumnLayout {
                visible: page.running && SearchEngine.results.count === 0
                anchors.centerIn: parent
                spacing: Theme.sp(3)
                UiSpinner {
                    Layout.alignment: Qt.AlignHCenter
                    size: 20
                }
                Text {
                    text: qsTr("Asking the trackers…")
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                }
            }
        }
    }

    UiToast {
        id: toast
        objectName: "searchToast"
    }

    PluginsDialog {
        id: pluginsDialog
    }

    ReleasesDialog {
        id: releasesDialog
    }

    // --- Pieces ---------------------------------------------------------------------------------
    // A switch with its label (a click on the label toggles it too)
    component LabeledSwitch: RowLayout {
        id: ls
        property string text
        property alias checked: sw.checked
        spacing: Theme.sp(2)
        UiSwitch {
            id: sw
            Accessible.name: ls.text
        }
        Text {
            text: ls.text
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            TapHandler { onTapped: sw.toggle() }
        }
    }

    component ViewButton: AbstractButton {
        id: vb
        property string view
        property string iconPath
        readonly property bool current: page.view === view

        implicitWidth: 30
        implicitHeight: 30
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: page.setView(view)

        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.checked: current

        background: Rectangle {
            radius: Theme.radiusCtl
            color: vb.current ? Theme.muted : vb.hovered ? Theme.alpha(Theme.muted, 0.6) : Theme.alpha(Theme.muted, 0)
            border.width: vb.current ? 1 : 0
            border.color: Theme.input
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                path: vb.iconPath
                size: 15
                strokeWidth: 1.9
                color: vb.current ? Theme.text : Theme.textDim
            }
        }
        UiTooltip {
            text: vb.text
            shown: vb.hovered
        }
    }

    // A film poster from Posters. Until (or unless) one is found: a tinted cover with the Flux mark in the
    // middle and, when there is room, the film's title and year under it.
    component Poster: Rectangle {
        id: poster
        property var film: ({})
        readonly property string url: Posters.revision >= 0 && film.key ? Posters.poster(film.key) : ""
        readonly property real hue: {
            let h = 0
            const t = film.title || ""
            for (let i = 0; i < t.length; ++i)
                h = (h * 31 + t.charCodeAt(i)) % 360
            return h / 360
        }

        radius: 6
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.hsla(poster.hue, 0.25, 0.20, 1) }
            GradientStop { position: 1; color: Qt.hsla((poster.hue + 0.06) % 1, 0.28, 0.10, 1) }
        }
        Component.onCompleted: {
            if (film.key)
                Posters.request(film.key, film.title, film.original, film.year, film.series)
        }
        onFilmChanged: {
            if (film.key)
                Posters.request(film.key, film.title, film.original, film.year, film.series)
        }

        ColumnLayout {
            objectName: "posterPlaceholder"
            anchors.centerIn: parent
            width: parent.width - 2 * Math.max(4, parent.width * 0.1)
            visible: image.status !== Image.Ready
            spacing: Math.max(4, poster.width * 0.05)

            // the Flux mark on a soft tile
            Rectangle {
                readonly property real side: poster.width < 60 ? Math.min(poster.width * 0.62, 22) : Math.min(48, poster.width * 0.26)
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: side
                implicitHeight: side
                radius: side * 0.25
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Icon {
                    anchors.centerIn: parent
                    path: Icons.logo
                    size: parent.side * 0.62
                    strokeWidth: 2.4
                    color: Qt.rgba(1, 1, 1, 0.82)
                }
            }
            Text {
                visible: poster.width >= 100
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: poster.film.title || ""
                color: Qt.rgba(1, 1, 1, 0.88)
                font.family: Theme.fontText
                font.pixelSize: Math.round(Math.min(15, Math.max(12, poster.width * 0.075)))
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            Text {
                visible: poster.width >= 100
                Layout.fillWidth: true
                text: [poster.film.original && poster.film.original !== poster.film.title ? poster.film.original : "",
                       poster.film.year > 0 ? String(poster.film.year) : ""].filter(t => t !== "").join(" · ")
                color: Qt.rgba(1, 1, 1, 0.55)
                font.family: Theme.fontText
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
        Image {
            id: image
            anchors.fill: parent
            source: poster.url
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.ceil(poster.width * 2)
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durMed }
            }
            // the picture takes the poster's rounded corners
            layer.enabled: status === Image.Ready && poster.radius > 0
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: posterMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }
        Rectangle {
            id: posterMask
            anchors.fill: parent
            radius: poster.radius
            visible: false
            layer.enabled: true
        }
        // the outline over the picture
        Rectangle {
            anchors.fill: parent
            radius: poster.radius
            color: "transparent"
            border.width: poster.border.width
            border.color: poster.border.color
        }
    }

    component EmptyState: ColumnLayout {
        id: es
        property string iconPath
        property string title
        property string text
        default property alias actions: actionRow.data

        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: Theme.sp(2)

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Theme.sp(2)
            implicitWidth: 40
            implicitHeight: 40
            radius: Theme.radiusCtl
            color: Theme.muted
            Icon {
                anchors.centerIn: parent
                path: es.iconPath
                size: 20
                strokeWidth: 1.75
                color: Theme.text
            }
        }
        Text {
            Layout.fillWidth: true
            text: es.title
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: 16
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            text: es.text
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            lineHeight: 1.3
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.sp(3)
            spacing: Theme.sp(2)
            visible: children.length > 0
        }
    }

    component HeaderCell: AbstractButton {
        id: hc
        property string sortKey
        property bool alignRight: false
        readonly property bool sorted: sortKey !== "" && resultsFilter.sortKey === sortKey

        Layout.fillHeight: true
        Layout.rightMargin: alignRight ? 12 : 0
        enabled: sortKey !== ""
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: page.sortBy(sortKey)

        Accessible.role: Accessible.ColumnHeader
        Accessible.name: text

        background: null
        contentItem: RowLayout {
            spacing: 4
            layoutDirection: hc.alignRight ? Qt.RightToLeft : Qt.LeftToRight
            Text {
                text: hc.text
                color: hc.hovered || hc.sorted ? Theme.text : Theme.textFaint
                Behavior on color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }
                font.family: Theme.fontText
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.6
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
                Layout.fillWidth: !hc.alignRight
            }
            Icon {
                visible: hc.sorted
                path: resultsFilter.descending ? Icons.chevronDown : Icons.chevronUp
                size: 12
                strokeWidth: 2.25
                color: Theme.text
            }
            Item { Layout.fillWidth: hc.alignRight }
        }
    }

    readonly property bool _wide: list.width >= 900

    component ResultsHeader: Rectangle {
        height: 36
        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.04) : Theme.background

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp(6) + 44
            anchors.rightMargin: Theme.sp(3)
            spacing: 0
            HeaderCell { text: qsTr("Name"); sortKey: "name"; Layout.fillWidth: true; Layout.minimumWidth: 160 }
            HeaderCell { text: qsTr("Size"); sortKey: "size"; alignRight: true; Layout.preferredWidth: 88 }
            HeaderCell { text: qsTr("Seeds"); sortKey: "seeds"; alignRight: true; Layout.preferredWidth: 72 }
            HeaderCell { text: qsTr("Leechers"); sortKey: "leechers"; alignRight: true; Layout.preferredWidth: 72 }
            HeaderCell { text: qsTr("Tracker"); sortKey: "engine"; Layout.preferredWidth: 130; Layout.leftMargin: 12 }
            HeaderCell { text: qsTr("Published"); sortKey: "published"; alignRight: true; Layout.preferredWidth: 96; visible: page._wide }
            Item { Layout.preferredWidth: 100 }
        }
    }

    component Cell: Text {
        property bool alignRight: false
        property bool dim: false
        Layout.fillHeight: true
        Layout.rightMargin: alignRight ? 12 : 0
        color: dim ? Theme.textFaint : Theme.text
        font.family: Theme.fontMono
        font.pixelSize: 12
        font.features: { "tnum": 1 }
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // Download / watch buttons of a release
    component ReleaseActions: RowLayout {
        id: ra
        property int row: -1
        property string fileUrl
        property string name
        property bool downloaded: false
        property bool showPage: true
        readonly property bool watchable: fileUrl.toLowerCase().startsWith("magnet:")
        spacing: 2

        UiButton {
            objectName: "searchWatch"
            size: "iconSm"
            variant: "ghost"
            iconPath: Icons.play
            focusPolicy: Qt.NoFocus
            visible: ra.watchable
            Accessible.name: qsTr("Watch %1 without downloading").arg(ra.name)
            onClicked: page.watchRequested(ra.fileUrl)
            UiTooltip {
                text: qsTr("Watch without downloading")
                shown: parent.hovered
            }
        }
        UiButton {
            visible: ra.showPage
            size: "iconSm"
            variant: "ghost"
            iconPath: Icons.externalLink
            focusPolicy: Qt.NoFocus
            Accessible.name: qsTr("Open the page of %1").arg(ra.name)
            onClicked: SearchEngine.openPage(ra.row)
            UiTooltip {
                text: qsTr("Open description page")
                shown: parent.hovered
            }
        }
        UiButton {
            size: "iconSm"
            variant: ra.downloaded ? "ghost" : "secondary"
            iconPath: ra.downloaded ? Icons.check : Icons.download
            focusPolicy: Qt.NoFocus
            Accessible.name: ra.downloaded ? qsTr("Added: %1").arg(ra.name) : qsTr("Download %1").arg(ra.name)
            onClicked: SearchEngine.download(ra.row)
            UiTooltip {
                text: ra.downloaded ? qsTr("Added") : qsTr("Download")
                shown: parent.hovered
            }
        }
    }

    component ResultRow: Rectangle {
        id: rr

        required property int index
        required property string name
        required property real size
        required property real seeds
        required property real leechers
        required property string engine
        required property var published
        required property bool downloaded
        required property string fileUrl

        readonly property var film: Posters.film(name)
        readonly property int sourceRow: resultsFilter.sourceRow(index)

        height: 52
        color: hover.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durFast }
        }

        Accessible.role: Accessible.Row
        Accessible.name: name

        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    resultMenu.row = rr.sourceRow
                    resultMenu.fileUrl = rr.fileUrl
                    resultMenu.popup()
                }
            }
            onDoubleClicked: SearchEngine.download(rr.sourceRow)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp(6)
            anchors.rightMargin: Theme.sp(3)
            spacing: 0

            Poster {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 40
                Layout.rightMargin: 16
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                film: rr.film
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.rightMargin: 12
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: rr.name
                    color: rr.downloaded ? Theme.textDim : Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: page.filmLine(rr.film)
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    elide: Text.ElideRight
                }
            }
            Cell {
                Layout.preferredWidth: 88
                alignRight: true
                dim: rr.size < 0
                text: rr.size >= 0 ? Format.size(rr.size) : "—"
            }
            Cell {
                Layout.preferredWidth: 72
                alignRight: true
                text: rr.seeds >= 0 ? rr.seeds.toLocaleString(Qt.locale(), "f", 0) : "—"
                color: rr.seeds > 0 ? Theme.upload : Theme.textFaint
            }
            Cell {
                Layout.preferredWidth: 72
                alignRight: true
                dim: rr.leechers <= 0
                text: rr.leechers >= 0 ? rr.leechers.toLocaleString(Qt.locale(), "f", 0) : "—"
            }
            Item {
                Layout.preferredWidth: 130
                Layout.fillHeight: true
                Layout.leftMargin: 12
                UiBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width)
                    text: page.trackerName(rr.engine)
                }
            }
            Cell {
                visible: page._wide
                Layout.preferredWidth: 96
                alignRight: true
                dim: !rr.published || isNaN(rr.published)
                text: rr.published && !isNaN(rr.published) ? rr.published.toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "—"
            }
            ReleaseActions {
                Layout.preferredWidth: 100
                Layout.alignment: Qt.AlignVCenter
                layoutDirection: Qt.RightToLeft
                row: rr.sourceRow
                fileUrl: rr.fileUrl
                name: rr.name
                downloaded: rr.downloaded
            }
        }
    }

    // A film: its poster, title, year and what is on offer; a click lists its releases
    component FilmCard: Item {
        id: card
        required property var modelData

        Accessible.role: Accessible.Button
        Accessible.name: modelData.title

        HoverHandler { id: cardHover }
        TapHandler { onTapped: releasesDialog.show(card.modelData) }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sp(2)
            anchors.bottomMargin: Theme.sp(4)
            spacing: Theme.sp(2)

            Poster {
                id: cardPoster
                Layout.fillWidth: true
                Layout.preferredHeight: width * 1.5
                radius: 8
                film: card.modelData
                border.width: 1
                border.color: cardHover.hovered ? Theme.alpha(Theme.text, 0.3) : Theme.border
                scale: cardHover.hovered && !Theme.reducedMotion ? 1.02 : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
                }

                // what is on offer, top left; the release count, top right
                Row {
                    x: 6
                    y: 6
                    spacing: 4
                    Repeater {
                        model: card.modelData.qualities.slice(0, 2)
                        Rectangle {
                            required property string modelData
                            implicitWidth: ql.implicitWidth + 10
                            implicitHeight: 18
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.62)
                            Text {
                                id: ql
                                anchors.centerIn: parent
                                text: modelData === "2160p" ? "4K" : modelData
                                color: "#FAFAFA"
                                font.family: Theme.fontText
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    implicitWidth: countText.implicitWidth + 10
                    implicitHeight: 18
                    radius: 4
                    color: Qt.rgba(0, 0, 0, 0.62)
                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: card.modelData.count
                        color: "#FAFAFA"
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }
                }
            }
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
                text: [card.modelData.year > 0 ? String(card.modelData.year) : "",
                       qsTr("%n release(s)", "", card.modelData.count),
                       card.modelData.seeds > 0 ? qsTr("up to %1 seeds").arg(card.modelData.seeds) : ""]
                      .filter(t => t !== "").join(" · ")
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                elide: Text.ElideRight
            }
        }
    }

    // The releases of one film, best seeded first, to download or watch
    component ReleasesDialog: UiDialog {
        id: rd
        objectName: "releasesDialog"
        property var film: ({ releases: [] })
        function show(f) {
            film = f
            open()
        }
        preferredWidth: 860
        title: film.title || ""
        description: [film.original && film.original !== film.title ? film.original : "",
                      film.year > 0 ? String(film.year) : "",
                      qsTr("%n release(s)", "", film.count || 0)].filter(t => t !== "").join(" · ")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp(5)

            Poster {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 150
                Layout.preferredHeight: 225
                radius: 8
                film: rd.film
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(420, releaseList.contentHeight + 2)
                radius: Theme.radiusCtl + 2
                color: "transparent"
                border.width: 1
                border.color: Theme.border
                clip: true

                ListView {
                    id: releaseList
                    objectName: "releaseList"
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    model: [...rd.film.releases].sort((a, b) => b.seeds - a.seeds)
                    delegate: Item {
                        id: rel
                        required property var modelData
                        required property int index
                        width: releaseList.width
                        height: 54

                        Rectangle {
                            visible: rel.index > 0
                            width: parent.width
                            height: 1
                            color: Theme.border
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.sp(4)
                            anchors.rightMargin: Theme.sp(2)
                            spacing: Theme.sp(3)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    Layout.fillWidth: true
                                    text: rel.modelData.name
                                    color: rel.modelData.downloaded ? Theme.textDim : Theme.text
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: [page.trackerName(rel.modelData.engine),
                                           rel.modelData.size >= 0 ? Format.size(rel.modelData.size) : "",
                                           rel.modelData.quality === "2160p" ? "4K" : rel.modelData.quality].filter(t => t !== "").join(" · ")
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textXs
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                Layout.preferredWidth: 72
                                horizontalAlignment: Text.AlignRight
                                text: rel.modelData.seeds >= 0 ? "↑ " + rel.modelData.seeds : "—"
                                color: rel.modelData.seeds > 0 ? Theme.upload : Theme.textFaint
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                            }
                            ReleaseActions {
                                row: rel.modelData.row
                                fileUrl: rel.modelData.fileUrl
                                name: rel.modelData.name
                                downloaded: rel.modelData.downloaded
                                showPage: true
                            }
                        }
                    }
                }
            }
        }
        footerItems: [
            UiButton {
                variant: "outline"
                text: qsTr("Close")
                onClicked: rd.close()
            }
        ]
    }

    UiMenu {
        id: resultMenu
        property int row: -1
        property string fileUrl
        UiMenuItem {
            visible: resultMenu.fileUrl.toLowerCase().startsWith("magnet:")
            text: qsTr("Watch without downloading")
            iconPath: Icons.play
            onTriggered: page.watchRequested(resultMenu.fileUrl)
        }
        UiMenuItem { text: qsTr("Download"); iconPath: Icons.download; onTriggered: SearchEngine.download(resultMenu.row) }
        UiMenuItem { text: qsTr("Open description page"); iconPath: Icons.externalLink; onTriggered: SearchEngine.openPage(resultMenu.row) }
    }
}
