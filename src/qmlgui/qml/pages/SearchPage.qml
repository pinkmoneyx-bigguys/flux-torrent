import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Tracker search: a query bar (words, category, plugins), the results as a shadcn data table that fills
// while trackers answer, and the plugin manager. Needs Python and at least one plugin; both missing
// states explain what to do.
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
    property string category: "all"
    // "Watch without downloading" on a result (a magnet link)
    signal watchRequested(string source)
    property string plugin: "enabled"

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
        resultsFilter.search = ""
        resultFilterInput.text = ""
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

    SearchResultsFilter {
        id: resultsFilter
        sourceModel: SearchEngine.results
        sortKey: "seeds"
        descending: true
        search: resultFilterInput.text
        seededOnly: seededSwitch.checked
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

        PageHeader {
            Layout.fillWidth: true
            title: page.title

            UiButton {
                objectName: "pluginsButton"
                variant: "outline"
                iconPath: Icons.puzzle
                text: SearchEngine.plugins.length > 0
                      ? qsTr("Sources · %1").arg(SearchEngine.enabledPluginCount)
                      : qsTr("Sources")
                enabled: SearchEngine.pythonAvailable || SearchEngine.plugins.length > 0
                onClicked: pluginsDialog.open()
            }
        }

        // --- Query ------------------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            spacing: Theme.sp(2)
            enabled: page.ready

            UiInput {
                id: queryInput
                objectName: "searchQuery"
                Layout.fillWidth: true
                implicitHeight: 36
                iconPath: Icons.search
                placeholderText: qsTr("What are you looking for?")
                onAccepted: page.search()
                // the last query stays in the field when coming back to the page
                Component.onCompleted: text = SearchEngine.pattern
            }
            UiSelect {
                objectName: "searchCategory"
                implicitHeight: 36
                Layout.preferredWidth: 170
                text: qsTr("Category")
                currentKey: page.category
                model: SearchEngine.categories.map(c => ({ key: c.key, label: page.categoryLabel(c.key) }))
                onActivated: key => page.category = key
            }
            UiSelect {
                objectName: "searchPlugin"
                implicitHeight: 36
                Layout.preferredWidth: 200
                text: qsTr("Sources")
                currentKey: page.plugin
                model: [{ key: "enabled", label: qsTr("All enabled sources") }]
                       .concat(SearchEngine.plugins.filter(p => p.enabled).map(p => ({ key: p.name, label: p.fullName })))
                onActivated: key => page.plugin = key
            }
            UiButton {
                objectName: "searchButton"
                size: "default"
                variant: page.running ? "outline" : "default"
                iconPath: page.running ? Icons.x : Icons.search
                text: page.running ? qsTr("Stop") : qsTr("Search")
                enabled: page.running || queryInput.text.trim() !== ""
                onClicked: page.running ? SearchEngine.stop() : page.search()
            }
        }

        // --- Results toolbar ----------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            Layout.bottomMargin: Theme.sp(3)
            Layout.preferredHeight: 32
            spacing: Theme.sp(3)
            visible: page.ready && SearchEngine.status !== "idle"

            UiSpinner {
                visible: page.running
            }
            Text {
                objectName: "searchStatus"
                Layout.fillWidth: true
                text: {
                    const n = SearchEngine.results.count
                    switch (SearchEngine.status) {
                    case "running": return qsTr("Searching for “%1”… %n result(s) so far", "", n).arg(SearchEngine.pattern)
                    case "failed": return SearchEngine.error
                    case "cancelled": return qsTr("Stopped. %n result(s) for “%1”", "", n).arg(SearchEngine.pattern)
                    default: return qsTr("%n result(s) for “%1”", "", n).arg(SearchEngine.pattern)
                    }
                }
                color: SearchEngine.status === "failed" ? Theme.error : Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: Theme.sp(2)
                UiSwitch {
                    id: seededSwitch
                    Accessible.name: seededLabel.text
                }
                Text {
                    id: seededLabel
                    text: qsTr("With seeds only")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    TapHandler { onTapped: seededSwitch.toggle() }
                }
            }
            UiInput {
                id: resultFilterInput
                objectName: "searchResultFilter"
                Layout.preferredWidth: 240
                iconPath: Icons.filter
                placeholderText: qsTr("Filter results…")
            }
        }

        // --- Results table ------------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.bottomMargin: Theme.sp(6)
            Layout.topMargin: page.ready && SearchEngine.status !== "idle" ? 0 : Theme.sp(4)
            radius: Theme.radiusCtl + 2
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            clip: true

            ListView {
                id: list
                objectName: "searchList"
                anchors.fill: parent
                anchors.margins: 1
                visible: page.ready && resultsFilter.count > 0
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
                title: SearchEngine.results.count > 0 ? qsTr("No results match the filter")
                     : SearchEngine.status === "failed" ? qsTr("The search failed") : qsTr("Nothing found")
                text: SearchEngine.results.count > 0 ? qsTr("Clear the filter to see all %n result(s).", "", SearchEngine.results.count)
                    : SearchEngine.status === "failed" ? SearchEngine.error
                    : qsTr("Try other words, another category or more plugins.")

                UiButton {
                    visible: SearchEngine.results.count > 0
                    variant: "outline"
                    text: qsTr("Clear filter")
                    onClicked: {
                        resultFilterInput.text = ""
                        seededSwitch.checked = false
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

    // --- Pieces ---------------------------------------------------------------------------------
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
                color: hc.hovered || hc.sorted ? Theme.text : Theme.textDim
                Behavior on color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: !hc.alignRight
            }
            Icon {
                visible: hc.sorted
                path: resultsFilter.descending ? Icons.chevronDown : Icons.chevronUp
                size: 14
                strokeWidth: 2
                color: Theme.text
            }
            Item { Layout.fillWidth: hc.alignRight }
        }
    }

    readonly property bool _wide: list.width >= 900

    component ResultsHeader: Rectangle {
        height: 40
        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.04) : "#141414"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 4
            spacing: 0
            HeaderCell { text: qsTr("Name"); sortKey: "name"; Layout.fillWidth: true; Layout.minimumWidth: 160 }
            HeaderCell { text: qsTr("Size"); sortKey: "size"; alignRight: true; Layout.preferredWidth: 96 }
            HeaderCell { text: qsTr("Seeds"); sortKey: "seeds"; alignRight: true; Layout.preferredWidth: 80 }
            HeaderCell { text: qsTr("Leechers"); sortKey: "leechers"; alignRight: true; Layout.preferredWidth: 88 }
            HeaderCell { text: qsTr("Tracker"); sortKey: "engine"; Layout.preferredWidth: 150; Layout.leftMargin: 16 }
            HeaderCell { text: qsTr("Published"); sortKey: "published"; alignRight: true; Layout.preferredWidth: 110; visible: page._wide }
            Item { Layout.preferredWidth: 108 }
        }
    }

    component Cell: Text {
        property bool alignRight: false
        property bool dim: false
        Layout.fillHeight: true
        Layout.rightMargin: alignRight ? 12 : 0
        color: dim ? Theme.textFaint : Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.textSm
        font.features: { "tnum": 1 }
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
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
        readonly property bool watchable: fileUrl.toLowerCase().startsWith("magnet:")

        readonly property string trackerName: {
            for (const p of SearchEngine.plugins) {
                if (p.name === engine)
                    return p.fullName
            }
            return engine
        }

        height: 40
        color: hover.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durFast }
        }

        Accessible.role: Accessible.Row
        Accessible.name: name

        function download() {
            SearchEngine.download(resultsFilter.sourceRow(rr.index))
        }

        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    resultMenu.row = resultsFilter.sourceRow(rr.index)
                    resultMenu.fileUrl = rr.fileUrl
                    resultMenu.popup()
                }
            }
            onDoubleClicked: rr.download()
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 4
            spacing: 0

            Cell {
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.rightMargin: 12
                text: rr.name
                font.weight: Font.Medium
                color: rr.downloaded ? Theme.textDim : Theme.text
            }
            Cell {
                Layout.preferredWidth: 96
                alignRight: true
                dim: rr.size < 0
                text: rr.size >= 0 ? Format.size(rr.size) : "—"
            }
            Cell {
                Layout.preferredWidth: 80
                alignRight: true
                text: rr.seeds >= 0 ? rr.seeds.toLocaleString(Qt.locale(), "f", 0) : "—"
                color: rr.seeds > 0 ? Theme.upload : Theme.textFaint
            }
            Cell {
                Layout.preferredWidth: 88
                alignRight: true
                dim: rr.leechers <= 0
                text: rr.leechers >= 0 ? rr.leechers.toLocaleString(Qt.locale(), "f", 0) : "—"
            }
            Item {
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                Layout.leftMargin: 16
                UiBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width)
                    text: rr.trackerName
                }
            }
            Cell {
                visible: page._wide
                Layout.preferredWidth: 110
                alignRight: true
                dim: !rr.published || isNaN(rr.published)
                text: rr.published && !isNaN(rr.published) ? rr.published.toLocaleDateString(Qt.locale(), Locale.ShortFormat) : "—"
            }
            RowLayout {
                Layout.preferredWidth: 108
                Layout.fillHeight: true
                spacing: 2
                UiButton {
                    objectName: "searchWatch"
                    size: "iconSm"
                    variant: "ghost"
                    iconPath: Icons.play
                    focusPolicy: Qt.NoFocus
                    // always in view: watching straight from the results is the point
                    visible: rr.watchable
                    Accessible.name: qsTr("Watch %1 without downloading").arg(rr.name)
                    onClicked: page.watchRequested(rr.fileUrl)

                    UiTooltip {
                        text: qsTr("Watch without downloading")
                        shown: parent.hovered
                    }
                }
                UiButton {
                    size: "iconSm"
                    variant: "ghost"
                    iconPath: Icons.externalLink
                    focusPolicy: Qt.NoFocus
                    opacity: hover.hovered ? 1 : 0
                    Accessible.name: qsTr("Open the page of %1").arg(rr.name)
                    onClicked: SearchEngine.openPage(resultsFilter.sourceRow(rr.index))
                }
                UiButton {
                    size: "iconSm"
                    variant: rr.downloaded ? "ghost" : "secondary"
                    iconPath: rr.downloaded ? Icons.check : Icons.download
                    focusPolicy: Qt.NoFocus
                    Accessible.name: rr.downloaded ? qsTr("Added: %1").arg(rr.name) : qsTr("Download %1").arg(rr.name)
                    onClicked: rr.download()
                }
            }
        }
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
