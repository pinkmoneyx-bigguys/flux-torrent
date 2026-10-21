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
    property string view: UiSettings.layoutValue("searchView", "cards")
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

    // The mouse wheel: a generous step with a short glide (Qt's own steps are small and jump); several
    // notches add up. Touchpads keep scrolling as they do.
    // Each notch moves a goal by `step`; the view eases toward it every frame (WheelGlide), so notches in a
    // row make one continuous glide instead of a start and a stop each.
    function wheelScroll(flickable, glide, event, step) {
        const from = glide.running ? glide.goal : flickable.contentY
        glide.flickable = flickable
        glide.goal = glideLimit(flickable, from - event.angleDelta.y / 120 * (step || 240))
        glide.start()
        event.accepted = true
    }
    function glideLimit(flickable, y) {
        const top = flickable.originY
        const bottom = Math.max(top, flickable.originY + flickable.contentHeight - flickable.height)
        return Math.max(top, Math.min(bottom, y))
    }
    function glideFrame(glide) {
        const f = glide.flickable
        // a drag or a flick takes over; the end may have moved as rows were measured
        if (!f || f.moving) {
            glide.stop()
            return
        }
        glide.goal = glideLimit(f, glide.goal)
        const d = glide.goal - f.contentY
        if (Math.abs(d) < 0.5) {
            f.contentY = glide.goal
            glide.stop()
            return
        }
        f.contentY += d * (1 - Math.exp(-glide.frameTime * 14))
    }
    component WheelGlide: FrameAnimation {
        property real goal: 0
        property Flickable flickable
        running: false
        onTriggered: page.glideFrame(this)
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
        query: SearchEngine.pattern
        exact: page.exactOnly
    }
    // only releases whose titles name what was searched for (a new search starts that way again)
    property bool exactOnly: true
    Connections {
        target: SearchEngine
        function onStatusChanged() {
            if (SearchEngine.status === "running")
                page.exactOnly = true
        }
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
                    // as wide as the chosen one's name (translations run longer), within reason
                    Layout.preferredWidth: Math.min(260, Math.max(160, implicitWidth))
                    Layout.minimumWidth: Layout.preferredWidth
                    text: qsTr("Category")
                    currentKey: page.category
                    model: SearchEngine.categories.map(c => ({ key: c.key, label: page.categoryLabel(c.key) }))
                    onActivated: key => page.category = key
                }
                UiSelect {
                    objectName: "searchPlugin"
                    implicitHeight: 30
                    Layout.preferredWidth: Math.min(260, Math.max(190, implicitWidth))
                    Layout.minimumWidth: Layout.preferredWidth
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
                    // what the controls leave (eliding): the selects and switches keep their size
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    text: {
                        const n = SearchEngine.results.count
                        switch (SearchEngine.status) {
                        case "idle": return ""
                        case "running": return qsTr("Searching for “%1”… %n result(s) so far", "", n).arg(SearchEngine.pattern)
                        case "failed": return SearchEngine.error
                        case "cancelled": return qsTr("Stopped. %n result(s) for “%1”", "", n).arg(SearchEngine.pattern)
                        // (what is shown: the loose matches left out are counted by the button beside)
                        default: return page.view === "cards" && resultsFilter.groups.length > 0
                                 ? qsTr("%n film(s), %1 release(s) for “%2”", "", resultsFilter.groups.length).arg(n - resultsFilter.looseCount * (page.exactOnly ? 1 : 0)).arg(SearchEngine.pattern)
                                 : qsTr("%n result(s) for “%1”", "", n - resultsFilter.looseCount * (page.exactOnly ? 1 : 0)).arg(SearchEngine.pattern)
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

        // --- What has the words only in its genres or notes: left out, a click away -----------------
        Rectangle {
            objectName: "searchLooseBar"
            visible: page.hasResults && resultsFilter.looseCount > 0
            Layout.fillWidth: true
            implicitHeight: 38
            color: Theme.alpha(Theme.muted, 0.45)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp(5)
                anchors.rightMargin: Theme.sp(3)
                spacing: Theme.sp(2)
                Icon {
                    path: Icons.filter
                    size: 14
                    strokeWidth: 1.75
                    color: Theme.textDim
                }
                Text {
                    Layout.fillWidth: true
                    text: page.exactOnly
                          ? qsTr("Only titles with “%1”: %n result(s) that have it just in their genres or notes are hidden", "", resultsFilter.looseCount).arg(SearchEngine.pattern)
                          : qsTr("Showing everything the trackers found for “%1”, genres and notes too").arg(SearchEngine.pattern)
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    elide: Text.ElideRight
                }
                UiButton {
                    objectName: "searchLoose"
                    size: "sm"
                    variant: "ghost"
                    text: page.exactOnly ? qsTr("Show them") : qsTr("Hide them")
                    onClicked: page.exactOnly = !page.exactOnly
                }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.border
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
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: event => page.wheelScroll(list, listGlide, event)
                }
                WheelGlide { id: listGlide }

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
                // cards made a couple of rows ahead and used again, so scrolling doesn't build them on the way
                cacheBuffer: Math.max(0, cellHeight * 2)
                reuseItems: true
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: event => page.wheelScroll(grid, gridGlide, event, 280)
                }
                WheelGlide { id: gridGlide }
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
        // the picture kept on disk (Posters fetches it the first time)
        readonly property string url: Posters.revision >= 0 && film.key ? Posters.image(film.key) : ""
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
        // the picture itself, drawn by the shader below: cropped to fill and with the rounded corners
        Image {
            id: image
            visible: false
            source: poster.url
            asynchronous: true
            // decoded at the size it is shown at (twice, for sharp corners on high DPI screens)
            sourceSize.width: Math.ceil(poster.width * 2)
        }
        ShaderEffect {
            anchors.fill: parent
            visible: image.status === Image.Ready
            opacity: visible ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durMed }
            }
            property variant source: image
            property size size: Qt.size(width, height)
            property real radius: poster.radius
            // the part of the picture that fills the card, per axis
            readonly property real pictureAspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 1
            readonly property real cardAspect: height > 0 ? width / height : 1
            property size crop: pictureAspect > cardAspect ? Qt.size(cardAspect / pictureAspect, 1)
                                                           : Qt.size(1, pictureAspect / cardAspect)
            fragmentShader: "qrc:/flux/shaders/poster.frag.qsb"
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

    // A film's card: its poster, what it is about (Wikipedia, in the interface language) and a trailer, then
    // every release of it with its full name and what it is (quality, source, season, voice-overs), to narrow
    // down by quality, voice-over or words and to download or watch. The film's part is the top of the list:
    // it scrolls away with it, so a long list gets the whole height.
    component ReleasesDialog: UiDialog {
        id: rd
        objectName: "releasesDialog"

        property string filmKey
        property var snapshot: ({ releases: [], voices: [], qualities: [] })
        // the film as the results have it now (a download marks its release), else as it was opened
        readonly property var film: {
            const g = resultsFilter.groups.length >= 0 && filmKey !== "" ? resultsFilter.group(filmKey) : null
            return g && g.key ? g : snapshot
        }
        readonly property var about: FilmDetails.revision >= 0 && filmKey !== "" ? FilmDetails.details(filmKey) : ({})
        property string quality: "all"
        property string voice: ""
        property string order: "seeds"
        property string words: ""
        property bool expanded: false
        // not scrolled yet: the film's part growing (its description arriving) keeps the list under it
        property bool atTop: true
        // another film: the filter box empties
        signal reset()

        function show(f) {
            // a card carries no releases: the film with them, as it is now
            const full = resultsFilter.group(f.key)
            snapshot = full && full.key ? full : f
            filmKey = f.key
            quality = "all"
            voice = ""
            order = "seeds"
            words = ""
            expanded = false
            reset()
            FilmDetails.request(f.key, f.title, f.original, f.year, f.series)
            // opened: worth asking again for a poster none was found for a while ago
            Posters.retry(f.key, f.title, f.original, f.year, f.series)
            open()
            atTop = true
            releaseList.positionViewAtBeginning()
        }
        function trailer() {
            const local = Qt.locale().name.startsWith("ru") || Qt.locale().name.startsWith("uk")
            const name = local || !film.original ? film.title : film.original
            const query = [name, film.year > 0 ? String(film.year) : "", qsTr("trailer")].filter(t => t !== "").join(" ")
            Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + encodeURIComponent(query))
        }
        function qualityLabel(q) {
            return q === "2160p" ? "4K" : q
        }
        function audioLabel(kind) {
            switch (kind) {
            case "dub": return qsTr("Dubbing")
            case "mvo": return qsTr("Multi-voice")
            case "dvo": return qsTr("Two-voice")
            case "avo": return qsTr("Single-voice")
            case "pro": return qsTr("Professional")
            case "amateur": return qsTr("Amateur")
            case "sub": return qsTr("Subtitles")
            case "original": return qsTr("Original audio")
            }
            return kind
        }
        function tagLabel(tag) {
            switch (tag.kind) {
            case "season": return qsTr("Season %1").arg(tag.text)
            case "episodes": return qsTr("Episodes %1").arg(tag.text)
            case "audio": return audioLabel(tag.text)
            }
            return tag.text
        }

        // the releases as narrowed down and ordered
        readonly property var shown: {
            const want = words.toLowerCase().split(/\s+/).filter(w => w !== "")
            const v = voice.toLowerCase()
            const list = (film.releases || []).filter(r => {
                if (quality === "other" ? r.quality !== "" : (quality !== "all" && r.quality !== quality))
                    return false
                if (v !== "" && (r.voices || []).every(x => x.toLowerCase() !== v) && r.name.toLowerCase().indexOf(v) < 0)
                    return false
                const hay = (r.name + " " + (r.voices || []).join(" ") + " " + page.trackerName(r.engine)).toLowerCase()
                return want.every(w => hay.indexOf(w) >= 0)
            })
            const time = d => d && !isNaN(d) ? d.getTime() : 0
            switch (order) {
            case "newest": return list.sort((a, b) => time(b.published) - time(a.published))
            case "largest": return list.sort((a, b) => b.size - a.size)
            case "smallest": return list.sort((a, b) => (a.size < 0 ? Infinity : a.size) - (b.size < 0 ? Infinity : b.size))
            default: return list.sort((a, b) => b.seeds - a.seeds)
            }
        }
        readonly property var qualityTabs: {
            const releases = film.releases || []
            const count = q => releases.filter(r => r.quality === q).length
            const tabs = [{ key: "all", label: qsTr("All"), count: releases.length }]
            for (const q of film.qualities || [])
                tabs.push({ key: q, label: qualityLabel(q), count: count(q) })
            const other = count("")
            if (other > 0 && tabs.length > 1)
                tabs.push({ key: "other", label: qsTr("Other"), count: other })
            return tabs
        }

        preferredWidth: 1040
        height: Math.min(implicitHeight, (parent ? parent.height : implicitHeight) - 48)
        title: film.title || ""
        description: [film.original && film.original !== film.title ? film.original : "",
                      film.year > 0 ? String(film.year) : "",
                      film.series ? qsTr("Series") : ""].filter(t => t !== "").join(" · ")

        ListView {
            id: releaseList
            objectName: "releaseList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: contentHeight
            Layout.minimumHeight: 240
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse
                onWheel: event => {
                    rd.atTop = false
                    page.wheelScroll(releaseList, releaseGlide, event, 200)
                }
            }
            WheelGlide { id: releaseGlide }
            model: rd.shown
            // the film's part stays at the top: it scrolls away with the list and back only with it
            headerPositioning: ListView.InlineHeader
            // rows made ahead, so a glide down doesn't stop to build them
            cacheBuffer: 1200
            onMovementStarted: rd.atTop = false
            onModelChanged: {
                if (rd.atTop)
                    Qt.callLater(positionViewAtBeginning)
            }

            header: Rectangle {
                z: 2
                width: releaseList.width
                height: headerColumn.implicitHeight + Theme.sp(3)
                onHeightChanged: {
                    if (rd.atTop)
                        Qt.callLater(releaseList.positionViewAtBeginning)
                }
                // the dialog's own colour: rows pass under it when it comes back
                color: Theme.glass ? "#17151F" : Theme.background

                ColumnLayout {
                    id: headerColumn
                    width: parent.width
                    spacing: Theme.sp(4)

                    // --- What it is ---------------------------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(5)

                        Poster {
                            objectName: "releasesPoster"
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 180
                            radius: 8
                            film: rd.film
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            spacing: Theme.sp(3)

                            Text {
                                id: aboutText
                                objectName: "filmAbout"
                                Layout.fillWidth: true
                                visible: rd.about.state === "ready"
                                text: rd.about.text || ""
                                color: Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                                lineHeight: 1.35
                                wrapMode: Text.Wrap
                                maximumLineCount: rd.expanded ? 40 : 4
                                elide: Text.ElideRight
                                TapHandler {
                                    enabled: parent.truncated || rd.expanded
                                    onTapped: rd.expanded = !rd.expanded
                                }
                                HoverHandler {
                                    enabled: parent.truncated || rd.expanded
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                            // a quiet placeholder while the article is looked up
                            Column {
                                visible: rd.about.state === "loading"
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: [1, 0.92, 0.6]
                                    Rectangle {
                                        required property real modelData
                                        width: parent.width * modelData
                                        height: 10
                                        radius: 5
                                        color: Theme.muted
                                        opacity: 0.7
                                    }
                                }
                            }
                            Text {
                                visible: rd.about.state === "none"
                                Layout.fillWidth: true
                                text: qsTr("No description found for this title.")
                                color: Theme.textFaint
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                            }

                            RowLayout {
                                spacing: Theme.sp(2)
                                UiButton {
                                    objectName: "filmTrailer"
                                    variant: "secondary"
                                    iconPath: Icons.play
                                    text: qsTr("Trailer")
                                    onClicked: rd.trailer()
                                    UiTooltip {
                                        text: qsTr("Search YouTube for the trailer")
                                        shown: parent.hovered
                                    }
                                }
                                UiButton {
                                    visible: rd.about.state === "ready" && (rd.about.url || "") !== ""
                                    variant: "ghost"
                                    iconPath: Icons.externalLink
                                    text: qsTr("Wikipedia")
                                    onClicked: Qt.openUrlExternally(rd.about.url)
                                    UiTooltip {
                                        text: qsTr("The description is from Wikipedia (CC BY-SA)")
                                        shown: parent.hovered
                                    }
                                }
                                UiButton {
                                    objectName: "filmAboutMore"
                                    visible: rd.expanded || aboutText.truncated
                                    variant: "ghost"
                                    text: rd.expanded ? qsTr("Show less") : qsTr("Read more")
                                    onClicked: rd.expanded = !rd.expanded
                                }
                            }

                            // the voice-overs on offer, the most common first: a click picks the releases with one
                            Flow {
                                visible: (rd.film.voices || []).length > 0
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    height: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Voice-overs:")
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textXs
                                }
                                Repeater {
                                    model: (rd.film.voices || []).slice(0, 10)
                                    AbstractButton {
                                        id: voiceChip
                                        required property string modelData
                                        readonly property bool on: rd.voice === modelData
                                        height: 24
                                        leftPadding: 9
                                        rightPadding: 9
                                        hoverEnabled: true
                                        focusPolicy: Qt.NoFocus
                                        text: modelData
                                        Accessible.role: Accessible.CheckBox
                                        Accessible.checked: on
                                        onClicked: rd.voice = on ? "" : modelData
                                        background: Rectangle {
                                            radius: height / 2
                                            color: voiceChip.on ? Theme.primary : voiceChip.hovered ? Theme.hover : "transparent"
                                            border.width: voiceChip.on ? 0 : 1
                                            border.color: Theme.border
                                        }
                                        contentItem: Text {
                                            text: voiceChip.text
                                            color: voiceChip.on ? Theme.primaryText : Theme.text
                                            font.family: Theme.fontText
                                            font.pixelSize: Theme.textXs
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                                Text {
                                    visible: (rd.film.voices || []).length > 10
                                    height: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("+%1 more").arg((rd.film.voices || []).length - 10)
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textXs
                                }
                            }
                        }
                    }

                    // --- Narrowing the releases down ---------------------------------------------
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(2)

                        UiTabs {
                            objectName: "releaseQuality"
                            visible: rd.qualityTabs.length > 1
                            model: rd.qualityTabs
                            currentKey: rd.quality
                            onActivated: key => rd.quality = key
                        }
                        Item { Layout.fillWidth: true }
                        // gives way when the qualities take room
                        UiInput {
                            id: releaseFilter
                            objectName: "releaseFilter"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 120
                            Layout.maximumWidth: 240
                            iconPath: Icons.search
                            placeholderText: qsTr("Voice-over, tracker, season…")
                            onTextChanged: rd.words = text
                            Connections {
                                target: rd
                                function onReset() {
                                    releaseFilter.text = ""
                                }
                            }
                        }
                        UiSelect {
                            visible: (rd.film.voices || []).length > 0
                            Layout.preferredWidth: 160
                            model: [{ key: "", label: qsTr("Any voice-over") }].concat((rd.film.voices || []).map(v => ({ key: v, label: v })))
                            currentKey: rd.voice
                            onActivated: key => rd.voice = key
                            Accessible.name: qsTr("Voice-over")
                        }
                        UiSelect {
                            Layout.preferredWidth: 150
                            model: [
                                { key: "seeds", label: qsTr("Most seeds") },
                                { key: "newest", label: qsTr("Newest") },
                                { key: "largest", label: qsTr("Largest") },
                                { key: "smallest", label: qsTr("Smallest") }
                            ]
                            currentKey: rd.order
                            onActivated: key => rd.order = key
                            Accessible.name: qsTr("Order")
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
            }

            footer: Item {
                width: releaseList.width
                height: rd.shown.length === 0 ? 96 : 0
                Text {
                    anchors.centerIn: parent
                    visible: rd.shown.length === 0
                    text: qsTr("No releases match.")
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                }
            }

            delegate: Item {
                id: rel
                required property var modelData
                required property int index
                width: releaseList.width
                height: relRow.implicitHeight + 2 * Theme.sp(3)

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 1
                    radius: Theme.radiusCtl
                    color: relHover.hovered ? Theme.alpha(Theme.hover, 0.6) : "transparent"
                }
                HoverHandler { id: relHover }
                Rectangle {
                    visible: rel.index > 0
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                RowLayout {
                    id: relRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.sp(3)
                    anchors.rightMargin: Theme.sp(2)
                    spacing: Theme.sp(3)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        // the whole name: the voice-overs and the rest are in it
                        Text {
                            objectName: "releaseName"
                            Layout.fillWidth: true
                            text: rel.modelData.name
                            color: rel.modelData.downloaded ? Theme.textDim : Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                            lineHeight: 1.25
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: tagRepeater.count > 0 || voiceRepeater.count > 0
                            Repeater {
                                id: tagRepeater
                                model: rel.modelData.tags || []
                                Rectangle {
                                    id: tag
                                    required property var modelData
                                    readonly property color tone: modelData.kind === "quality" ? Theme.download
                                                                : modelData.kind === "hdr" ? Theme.warn
                                                                : modelData.kind === "audio" ? Theme.upload
                                                                : Theme.textDim
                                    readonly property bool strong: modelData.kind === "quality" || modelData.kind === "hdr" || modelData.kind === "audio"
                                    implicitWidth: tagText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 5
                                    color: strong ? Theme.alpha(tone, 0.14) : "transparent"
                                    border.width: strong ? 0 : 1
                                    border.color: Theme.border
                                    Text {
                                        id: tagText
                                        anchors.centerIn: parent
                                        text: rd.tagLabel(tag.modelData)
                                        color: tag.strong ? tag.tone : Theme.textDim
                                        font.family: Theme.fontText
                                        font.pixelSize: 11
                                        font.weight: tag.strong ? Font.Medium : Font.Normal
                                    }
                                }
                            }
                            Repeater {
                                id: voiceRepeater
                                model: (rel.modelData.voices || []).slice(0, 6)
                                Rectangle {
                                    id: voiceTag
                                    required property string modelData
                                    readonly property bool picked: rd.voice.toLowerCase() === modelData.toLowerCase()
                                    implicitWidth: voiceRow.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 5
                                    color: picked ? Theme.alpha(Theme.primary, 0.2) : Theme.muted
                                    Row {
                                        id: voiceRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            path: Icons.mic
                                            size: 11
                                            strokeWidth: 2
                                            color: Theme.textDim
                                        }
                                        Text {
                                            text: voiceTag.modelData
                                            color: Theme.text
                                            font.family: Theme.fontText
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: (rel.modelData.voices || []).length > 6
                                height: 20
                                verticalAlignment: Text.AlignVCenter
                                text: "+" + ((rel.modelData.voices || []).length - 6)
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: 11
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: [page.trackerName(rel.modelData.engine),
                                   rel.modelData.size >= 0 ? Format.size(rel.modelData.size) : "",
                                   rel.modelData.published && !isNaN(rel.modelData.published)
                                       ? rel.modelData.published.toLocaleDateString(Qt.locale(), Locale.ShortFormat) : ""]
                                  .filter(t => t !== "").join(" · ")
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            elide: Text.ElideRight
                        }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 64
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: rel.modelData.seeds >= 0 ? "↑ " + rel.modelData.seeds : "—"
                            color: rel.modelData.seeds > 0 ? Theme.upload : Theme.textFaint
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                            Accessible.name: qsTr("%1 seeds").arg(rel.modelData.seeds)
                        }
                        Text {
                            visible: rel.modelData.leechers >= 0
                            Layout.alignment: Qt.AlignRight
                            text: "↓ " + rel.modelData.leechers
                            color: Theme.textFaint
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            Accessible.name: qsTr("%1 peers").arg(rel.modelData.leechers)
                        }
                    }
                    ReleaseActions {
                        Layout.alignment: Qt.AlignVCenter
                        row: rel.modelData.row
                        fileUrl: rel.modelData.fileUrl
                        name: rel.modelData.name
                        downloaded: rel.modelData.downloaded
                        showPage: true
                    }
                }
            }
        }
        footerLeftItems: [
            Text {
                text: rd.shown.length === (rd.film.releases || []).length
                      ? qsTr("%n release(s)", "", rd.shown.length)
                      : qsTr("%1 of %2 releases").arg(rd.shown.length).arg((rd.film.releases || []).length)
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
            }
        ]
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
