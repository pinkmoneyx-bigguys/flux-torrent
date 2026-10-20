import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import Flux

// Transfers: the torrent table (shadcn data table) with search, multi-selection, row actions and a
// details pane for the focused torrent. The status filter comes from the sidebar (TransfersState).
Surface {
    id: page
    objectName: "page_transfers"

    property string title: qsTr("Transfers")
    property string hint: qsTr("Your torrents will appear here.")

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

    // --- Selection ------------------------------------------------------------------------------
    // id -> true; replaced (never mutated) on every change, so bindings that read it re-evaluate
    property var _selection: ({})
    // The torrent shown in the details pane and the anchor of shift-selection
    property string currentId: ""
    readonly property int selectedCount: Object.keys(_selection).length

    function isSelected(id) {
        return _selection[id] === true
    }
    function selectedIds() {
        return Object.keys(_selection)
    }
    function _set(ids) {
        const s = {}
        for (const id of ids)
            s[id] = true
        _selection = s
    }
    function selectOnly(id) {
        _set([id])
        currentId = id
    }
    function toggle(id) {
        const s = Object.assign({}, _selection)
        if (s[id])
            delete s[id]
        else
            s[id] = true
        _selection = s
        currentId = id
    }
    function selectRangeTo(id) {
        const from = filter.rowOf(currentId)
        const to = filter.rowOf(id)
        if (from < 0) {
            selectOnly(id)
            return
        }
        _set(filter.idsBetween(from, to))
    }
    function selectAll() {
        _set(filter.idsBetween(0, filter.count - 1))
    }
    function clearSelection() {
        _set([])
    }
    // The ids an action applies to: the selection, or the focused row when nothing is selected
    function targetIds() {
        const ids = selectedIds()
        return ids.length > 0 ? ids : (currentId !== "" ? [currentId] : [])
    }

    // --- Columns --------------------------------------------------------------------------------
    // Each column has a width the user can drag (kept in the profile); Name takes the rest. When Name
    // would get narrower than nameMin, the optional columns drop out, last in `optionalColumns` first.
    readonly property real tableWidth: table.width
    readonly property var defaultWidths: ({ size: 88, progress: 190, speed: 116, eta: 84, swarm: 92, ratio: 72 })
    readonly property var minWidths: ({ size: 56, progress: 110, speed: 88, eta: 48, swarm: 64, ratio: 48 })
    readonly property var optionalColumns: ["swarm", "eta", "ratio"]
    readonly property real nameMin: 200
    // checkbox, row menu and the row's side margins
    readonly property real chromeWidth: 28 + 36 + Theme.sp(6) + Theme.sp(3)
    property var widths: Object.assign({}, defaultWidths, UiSettings.columnWidths("transfers"))

    function cw(key) {
        return widths[key] ?? defaultWidths[key]
    }
    readonly property var shownColumns: {
        let used = chromeWidth + nameMin + cw("size") + cw("progress") + cw("speed")
        const shown = {}
        for (const key of optionalColumns) {
            if (used + cw(key) > tableWidth)
                break
            shown[key] = true
            used += cw(key)
        }
        return shown
    }
    function colVisible(key) {
        return optionalColumns.indexOf(key) < 0 || shownColumns[key] === true
    }
    // Width Name gets now
    function nameWidth() {
        let used = chromeWidth + cw("size") + cw("progress") + cw("speed")
        for (const key of optionalColumns)
            used += colVisible(key) ? cw(key) : 0
        return tableWidth - used
    }
    // Sets a column's width, held between its minimum and what Name can give up
    function resizeColumn(key, width) {
        const room = cw(key) + Math.max(0, nameWidth() - nameMin)
        const next = Object.assign({}, widths)
        next[key] = Math.round(Math.max(minWidths[key], Math.min(room, width)))
        widths = next
    }
    function resetColumn(key) {
        const next = Object.assign({}, widths)
        next[key] = defaultWidths[key]
        widths = next
        saveColumns()
    }
    function saveColumns() {
        const known = {}
        for (const key in defaultWidths)
            known[key] = cw(key)
        UiSettings.setColumnWidths("transfers", known)
    }

    // What a torrent holds, guessed from its name: the glyph and tint of the tile before it
    readonly property var kinds: ({
        video: { icon: Icons.film, color: "#F472B6" },
        audio: { icon: Icons.audio, color: "#FB923C" },
        disc: { icon: Icons.disc, color: "#A78BFA" },
        archive: { icon: Icons.data, color: "#2DD4BF" },
        app: { icon: Icons.app, color: "#34D399" },
        other: { icon: Icons.file, color: "#60A5FA" }
    })
    function kindOf(name) {
        const n = name.toLowerCase()
        if (/\.(mkv|mp4|avi|mov|webm|m4v|ts|wmv)$/.test(n) || /(2160p|1080p|720p|480p|\b4k\b|hevc|x26[45]|bluray|web-?dl|webrip|s\d\de\d\d)/.test(n))
            return "video"
        if (/\.(flac|mp3|ogg|opus|m4a|wav|aac)$/.test(n) || /\b(flac|mp3|discography|ost)\b/.test(n))
            return "audio"
        if (/\.(iso|img|dmg)$/.test(n) || /\b(iso|dvd)\b/.test(n))
            return "disc"
        if (/\.(zip|rar|7z|tar|gz|bz2|xz|zst|pbf|bz)$/.test(n) || /\b(dump|archive|backup)\b/.test(n))
            return "archive"
        if (/\.(exe|msi|appimage|deb|rpm|apk)$/.test(n))
            return "app"
        return "other"
    }

    TorrentFilterModel {
        id: filter
        sourceModel: TorrentListModel
        status: TransfersState.status
        search: searchInput.text
    }

    // Selection follows the filter: rows that disappear from view are no longer selected
    Connections {
        target: filter
        function onCountChanged() {
            const visible = {}
            for (const id of filter.idsBetween(0, filter.count - 1))
                visible[id] = true
            const kept = page.selectedIds().filter(id => visible[id])
            if (kept.length !== page.selectedCount)
                page._set(kept)
            if (page.currentId !== "" && !visible[page.currentId])
                page.currentId = ""
        }
    }

    // Header clicks cycle: natural direction (names A→Z, numbers largest first), reversed, queue order
    function sortBy(key) {
        const natural = key !== "name" && key !== "state"
        if (filter.sortKey !== key) {
            filter.sortKey = key
            filter.descending = natural
        } else if (filter.descending === natural) {
            filter.descending = !natural
        } else {
            filter.sortKey = ""
            filter.descending = false
        }
    }

    // --- Layout ---------------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // One bar: the title, the filter, and on the right the row count or the selection's actions.
        // (Adding torrents lives in the title bar.)
        PageHeader {
            Layout.fillWidth: true
            title: page.title
            subtitle: TransfersState.status === "all" ? "" : TransfersState.label(TransfersState.status)

            leading: UiInput {
                id: searchInput
                objectName: "transfersSearch"
                Layout.preferredWidth: Math.min(280, Math.max(160, page.width * 0.24))
                implicitHeight: 32
                iconPath: Icons.filter
                placeholderText: qsTr("Filter torrents…")
                field.Keys.onDownPressed: list.forceActiveFocus()
            }

            Text {
                visible: page.selectedCount === 0
                text: filter.count === TorrentListModel.count
                      ? qsTr("%n torrent(s)", "", filter.count)
                      : qsTr("%1 of %2").arg(filter.count).arg(TorrentListModel.count)
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
            }

            RowLayout {
                visible: page.selectedCount > 0
                spacing: Theme.sp(2)

                Text {
                    text: qsTr("%n selected", "", page.selectedCount)
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    Layout.rightMargin: Theme.sp(1)
                }
                UiButton {
                    variant: "outline"
                    iconPath: Icons.play
                    text: qsTr("Start")
                    onClicked: TorrentListModel.start(page.targetIds())
                }
                UiButton {
                    variant: "outline"
                    iconPath: Icons.pause
                    text: qsTr("Stop")
                    onClicked: TorrentListModel.stop(page.targetIds())
                }
                UiButton {
                    variant: "outline"
                    size: "icon"
                    iconPath: Icons.trash
                    Accessible.name: qsTr("Remove")
                    onClicked: removeDialog.ask(page.targetIds())
                }
                UiButton {
                    variant: "ghost"
                    size: "icon"
                    iconPath: Icons.x
                    Accessible.name: qsTr("Clear selection")
                    onClicked: page.clearSelection()
                }
            }
        }

        // --- Table ------------------------------------------------------------------------------
        Rectangle {
            // the table runs edge to edge under the header; its rows line up with the title
            id: tableFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            Item {
                id: table
                anchors.fill: parent

                ListView {
                    id: list
                    objectName: "transfersList"
                    anchors.fill: parent
                    model: filter
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    headerPositioning: ListView.OverlayHeader
                    keyNavigationEnabled: false
                    focus: true
                    activeFocusOnTab: true
                    reuseItems: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    add: Transition {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed }
                    }
                    remove: Transition {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast }
                    }
                    displaced: Transition {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; to: 1; duration: Theme.durFast }
                    }

                    header: TableHeader {
                        width: list.width
                        z: 2
                    }
                    delegate: TorrentRowDelegate {
                        width: list.width
                    }

                    function moveCurrent(delta, extend) {
                        if (filter.count === 0)
                            return
                        let row = filter.rowOf(page.currentId)
                        row = row < 0 ? 0 : Math.max(0, Math.min(filter.count - 1, row + delta))
                        const id = filter.idAt(row)
                        if (extend) {
                            page.selectRangeTo(id)
                            page.currentId = id
                        } else {
                            page.selectOnly(id)
                        }
                        list.positionViewAtIndex(row, ListView.Contain)
                    }

                    Keys.onUpPressed: event => moveCurrent(-1, event.modifiers & Qt.ShiftModifier)
                    Keys.onDownPressed: event => moveCurrent(1, event.modifiers & Qt.ShiftModifier)
                    Keys.onPressed: event => {
                        if (event.matches(StandardKey.SelectAll)) {
                            page.selectAll()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete) {
                            removeDialog.ask(page.targetIds())
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape && page.selectedCount > 0) {
                            page.clearSelection()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Space && page.currentId !== "") {
                            page.toggle(page.currentId)
                            event.accepted = true
                        }
                    }
                }

                // shadcn Empty: shown when there are no torrents at all, or the filter hides them all
                ColumnLayout {
                    objectName: "transfersEmpty"
                    visible: filter.count === 0
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 20
                    width: Math.min(parent.width - 48, 380)
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
                            path: TorrentListModel.count === 0 ? Icons.inbox : Icons.filter
                            size: 20
                            strokeWidth: 1.75
                            color: Theme.text
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: TorrentListModel.count === 0 ? qsTr("No torrents yet") : qsTr("Nothing matches")
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: TorrentListModel.count === 0
                              ? qsTr("Drop a .torrent file here, or add a file or a magnet link.")
                              : qsTr("No torrents match this filter.")
                        color: Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.sp(3)
                        spacing: Theme.sp(2)
                        visible: TorrentListModel.count === 0

                        UiButton {
                            iconPath: Icons.plus
                            text: qsTr("Add torrent")
                            onClicked: fileDialog.open()
                        }
                        UiButton {
                            variant: "outline"
                            iconPath: Icons.link
                            text: qsTr("Add link")
                            onClicked: addLinkDialog.open()
                        }
                    }
                    UiButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.sp(2)
                        visible: TorrentListModel.count > 0
                        variant: "outline"
                        text: qsTr("Clear filters")
                        onClicked: {
                            searchInput.text = ""
                            TransfersState.status = "all"
                        }
                    }
                }
            }
        }

        // --- Details ----------------------------------------------------------------------------
        TorrentDetailsPane {
            id: details
            objectName: "transfersDetails"
            readonly property bool open: page.currentId !== ""
            // the height the user dragged it to (kept in the profile), or 0 for about a third of the page
            property real chosenHeight: UiSettings.layoutValue("detailsHeight", 0)
            readonly property real maxHeight: Math.max(minHeight, page.height - 200)
            readonly property real minHeight: 150
            readonly property real openHeight: chosenHeight > 0 ? Math.max(minHeight, Math.min(maxHeight, chosenHeight))
                                                                : Math.max(220, Math.min(320, page.height * 0.36))
            Layout.fillWidth: true
            Layout.preferredHeight: open ? openHeight : 0
            Behavior on Layout.preferredHeight {
                enabled: !Theme.reducedMotion && !heightGrip.pressed
                NumberAnimation { duration: Theme.durMed; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
            }
            opacity: open ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durMed }
            }
            visible: open || Layout.preferredHeight > 1
            clip: true
            onCloseRequested: page.currentId = ""

            // Drag the top edge to resize; double-click for the automatic height
            MouseArea {
                id: heightGrip
                objectName: "detailsHeightGrip"
                property real startY
                property real startHeight
                y: Theme.sp(4) - 6
                width: parent.width
                height: 13
                z: 10
                hoverEnabled: true
                cursorShape: Qt.SplitVCursor
                preventStealing: true
                onPressed: mouse => {
                    startY = mapToItem(page, 0, mouse.y).y
                    startHeight = details.openHeight
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const dy = mapToItem(page, 0, mouse.y).y - startY
                    details.chosenHeight = Math.round(Math.max(details.minHeight, Math.min(details.maxHeight, startHeight - dy)))
                }
                onReleased: UiSettings.setLayoutValue("detailsHeight", details.chosenHeight)
                onDoubleClicked: {
                    details.chosenHeight = 0
                    UiSettings.setLayoutValue("detailsHeight", 0)
                }

                // a grabber pill on the separator while the pointer is on it
                Rectangle {
                    anchors.centerIn: parent
                    width: 36
                    height: 4
                    radius: 2
                    color: heightGrip.pressed ? Theme.ring : Theme.alpha(Theme.text, 0.35)
                    opacity: heightGrip.containsMouse || heightGrip.pressed ? 1 : 0
                    Behavior on opacity {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: Theme.durFast }
                    }
                }
            }
        }
        // the pane keeps the last torrent while it slides shut
        Connections {
            target: page
            function onCurrentIdChanged() {
                if (page.currentId !== "")
                    details.torrentId = page.currentId
            }
        }
    }

    // .torrent files dropped anywhere on the page
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            page.addSources(drop.urls)
            drop.accept()
        }
    }

    // --- Pieces ---------------------------------------------------------------------------------
    // The header and row share one cell layout. Every column but Name has an exact width (fixedWidth:
    // minimum = preferred = maximum), and Name fills from the same small base in every row, so nothing
    // shifts with the text in it. Figures use the mono face: digits keep their places as they change.
    component Cells: RowLayout {
        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: Theme.sp(6)
        anchors.rightMargin: Theme.sp(3)
    }

    component HeaderCell: AbstractButton {
        id: hc
        property string sortKey
        property bool alignRight: false
        readonly property bool sorted: sortKey !== "" && filter.sortKey === sortKey
        property real fixedWidth: -1
        // The column this cell heads, and the one its right edge resizes: its own, or for Name (which
        // takes the rest) the next one, which then gives way as the edge moves right
        property string column
        property string resizes: column

        Layout.preferredWidth: fixedWidth
        Layout.minimumWidth: fixedWidth >= 0 ? fixedWidth : 0
        Layout.maximumWidth: fixedWidth >= 0 ? fixedWidth : Number.POSITIVE_INFINITY
        Layout.fillHeight: true
        Layout.rightMargin: alignRight ? 12 : 0
        enabled: sortKey !== ""
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        onClicked: page.sortBy(sortKey)

        Accessible.role: Accessible.ColumnHeader
        Accessible.name: text

        ColumnResizer {
            objectName: "resizer_" + hc.column
            visible: hc.resizes !== ""
            // inside this cell (the next one would cover anything past its edge), flush with the boundary
            x: hc.width + hc.Layout.rightMargin - width
            column: hc.resizes
            invert: hc.resizes !== hc.column
        }

        background: null
        contentItem: RowLayout {
            spacing: 4
            layoutDirection: hc.alignRight ? Qt.RightToLeft : Qt.LeftToRight
            Text {
                Layout.maximumWidth: hc.width - (hc.sorted ? 16 : 0)
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
                horizontalAlignment: hc.alignRight ? Text.AlignRight : Text.AlignLeft
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                lineHeight: 0.95
                elide: Text.ElideRight
            }
            Icon {
                visible: hc.sorted
                path: filter.descending ? Icons.chevronDown : Icons.chevronUp
                size: 12
                strokeWidth: 2.25
                color: Theme.text
            }
            Item { Layout.fillWidth: true }
        }
    }

    // An 8 px grip on a column boundary: drag to resize, double-click for the default width
    component ColumnResizer: MouseArea {
        id: grip
        property string column
        // dragging right narrows the column (it sits to the right of the grip)
        property bool invert: false
        property real _startX
        property real _startWidth

        width: 8
        height: parent.height
        z: 2
        hoverEnabled: true
        cursorShape: Qt.SplitHCursor
        preventStealing: true

        onPressed: mouse => {
            _startX = mapToItem(page, mouse.x, 0).x
            _startWidth = page.cw(column)
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return
            const delta = mapToItem(page, mouse.x, 0).x - _startX
            page.resizeColumn(column, _startWidth + (invert ? -delta : delta))
        }
        onReleased: page.saveColumns()
        onDoubleClicked: page.resetColumn(column)

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: grip.pressed ? 2 : 1
            height: grip.pressed ? parent.height : parent.height * 0.5
            radius: 1
            color: grip.pressed ? Theme.ring : Theme.border
            opacity: grip.pressed || grip.containsMouse ? 1 : 0
            Behavior on opacity {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast }
            }
            Behavior on height {
                enabled: !Theme.reducedMotion
                NumberAnimation { duration: Theme.durFast }
            }
        }
    }

    component TableHeader: Rectangle {
        height: 44
        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.04) : "#111111"

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        Cells {
            Item {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                UiCheckBox {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: page.selectedCount > 0 && page.selectedCount === filter.count
                    partial: page.selectedCount > 0 && page.selectedCount < filter.count
                    Accessible.name: qsTr("Select all")
                    onClicked: page.selectedCount > 0 ? page.clearSelection() : page.selectAll()
                }
            }
            // starts over the name, past the kind tile
            HeaderCell {
                text: qsTr("Name"); sortKey: "name"; column: "name"; resizes: "size"
                Layout.fillWidth: true; Layout.minimumWidth: 20; Layout.preferredWidth: 20; Layout.leftMargin: 44
            }
            HeaderCell { text: qsTr("Size"); sortKey: "size"; column: "size"; alignRight: true; fixedWidth: page.cw("size") - 12 }
            HeaderCell { text: qsTr("Progress"); sortKey: "progress"; column: "progress"; fixedWidth: page.cw("progress") - 16; Layout.leftMargin: 16 }
            HeaderCell { text: qsTr("Speed"); sortKey: "dlSpeed"; column: "speed"; alignRight: true; fixedWidth: page.cw("speed") - 12 }
            HeaderCell {
                text: qsTr("ETA"); sortKey: "eta"; column: "eta"; alignRight: true
                fixedWidth: page.cw("eta") - 12; visible: page.colVisible("eta")
            }
            HeaderCell {
                objectName: "header_swarm"
                text: qsTr("Seeds / peers"); sortKey: "seeds"; column: "swarm"; alignRight: true
                fixedWidth: page.cw("swarm") - 12; visible: page.colVisible("swarm")
            }
            HeaderCell {
                text: qsTr("Ratio"); sortKey: "ratio"; column: "ratio"; alignRight: true
                fixedWidth: page.cw("ratio") - 12; visible: page.colVisible("ratio")
            }
            Item { Layout.preferredWidth: 36 }
        }
    }

    // A one-line cell; `mono` for figures
    component CellText: Text {
        property bool alignRight: false
        property bool dim: false
        property bool mono: false
        property real fixedWidth: -1

        Layout.preferredWidth: fixedWidth
        Layout.minimumWidth: fixedWidth >= 0 ? fixedWidth : 0
        Layout.maximumWidth: fixedWidth >= 0 ? fixedWidth : Number.POSITIVE_INFINITY
        Layout.fillHeight: true
        Layout.rightMargin: alignRight ? 12 : 0
        color: dim ? Theme.textFaint : Theme.text
        font.family: mono ? Theme.fontMono : Theme.fontText
        font.pixelSize: mono ? 12 : Theme.textSm
        font.features: { "tnum": 1 }
        horizontalAlignment: alignRight ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    // A small figure line inside a two-line cell; its digits roll when the figure changes
    component FigureLine: RollingText {
        Layout.fillWidth: true
        font.family: Theme.fontMono
        font.pixelSize: 12
        horizontalAlignment: Text.AlignRight
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durMed }
        }
    }

    // What the torrent holds, as a tinted tile
    component KindTile: Rectangle {
        id: tile
        property string kind: "other"
        readonly property var spec: page.kinds[kind] ?? page.kinds.other
        readonly property color tint: spec.color

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 32
        implicitHeight: 32
        radius: 9
        color: Theme.alpha(tint, 0.14)
        border.width: 1
        border.color: Theme.alpha(tint, 0.24)

        Icon {
            anchors.centerIn: parent
            path: tile.spec.icon
            size: 16
            strokeWidth: 1.75
            color: tile.tint
        }
    }

    // A small outline action under the name ("Watch")
    component RowChip: AbstractButton {
        id: chip
        property string iconPath

        implicitHeight: 18
        implicitWidth: chipRow.implicitWidth + 12
        hoverEnabled: true
        focusPolicy: Qt.NoFocus

        Accessible.role: Accessible.Button
        Accessible.name: text

        background: Rectangle {
            radius: 5
            color: chip.hovered ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.text, 0.06)
            border.width: 1
            border.color: Theme.border
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
        }
        contentItem: Item {
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 4
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.iconPath !== ""
                    path: chip.iconPath
                    size: 9
                    strokeWidth: 2.5
                    color: Theme.text
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: chip.text
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 11
                }
            }
        }
    }

    component TorrentRowDelegate: Rectangle {
        id: rowItem

        required property int index
        required property string torrentId
        required property string name
        required property string state
        required property string error
        required property real size
        required property real progress
        required property real dlSpeed
        required property real upSpeed
        required property real eta
        required property real ratio
        required property int seeds
        required property int seedsTotal
        required property int peers
        required property int peersTotal
        required property string category

        readonly property bool selected: page.isSelected(torrentId)
        readonly property bool focused: page.currentId === torrentId
        readonly property color stateColor: TorrentStatus.color(state)
        // a video in it can be watched now (streamed while it downloads)
        readonly property string watchKey: MediaLibraryModel.bestVideoOf(torrentId)

        height: 54
        color: selected ? Theme.muted : hover.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durFast }
        }

        Accessible.role: Accessible.Row
        Accessible.name: name
        Accessible.selected: selected

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => {
                list.forceActiveFocus()
                if (mouse.button === Qt.RightButton) {
                    if (!rowItem.selected)
                        page.selectOnly(rowItem.torrentId)
                    else
                        page.currentId = rowItem.torrentId
                    rowMenu.popup()
                    return
                }
                if (mouse.modifiers & Qt.ControlModifier)
                    page.toggle(rowItem.torrentId)
                else if (mouse.modifiers & Qt.ShiftModifier)
                    page.selectRangeTo(rowItem.torrentId)
                else
                    page.selectOnly(rowItem.torrentId)
            }
            onDoubleClicked: TorrentListModel.openFolder(rowItem.torrentId)
        }

        // keyboard focus marker: a 2 px bar on the left of the focused row
        Rectangle {
            visible: rowItem.focused && list.activeFocus
            width: 2
            height: parent.height
            color: Theme.ring
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        Cells {
            Item {
                Layout.preferredWidth: 28
                Layout.fillHeight: true
                UiCheckBox {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: rowItem.selected
                    focusPolicy: Qt.NoFocus
                    Accessible.name: qsTr("Select %1").arg(rowItem.name)
                    onClicked: page.toggle(rowItem.torrentId)
                }
            }

            // Kind tile, the name, and under it the state (or the error) with actions
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 64
                Layout.preferredWidth: 64
                Layout.fillHeight: true
                Layout.rightMargin: 12
                spacing: 12

                KindTile {
                    objectName: "kindTile"
                    kind: page.kindOf(rowItem.name)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 20
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: rowItem.name
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            objectName: "rowStatus"
                            // as wide as its text, or what is left before the chip, eliding then
                            Layout.fillWidth: true
                            Layout.maximumWidth: implicitWidth
                            text: (rowItem.state === "missing" || rowItem.state === "error") && rowItem.error !== ""
                                  ? rowItem.error : TorrentStatus.label(rowItem.state)
                            color: rowItem.stateColor
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durMed }
                            }
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            elide: Text.ElideRight
                        }
                        RowChip {
                            id: watchChip
                            objectName: "watchChip"
                            visible: rowItem.watchKey !== ""
                            Layout.minimumWidth: implicitWidth
                            iconPath: Icons.play
                            text: qsTr("Watch")
                            onClicked: page.playRequested(rowItem.watchKey)
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            CellText {
                fixedWidth: page.cw("size") - 12
                alignRight: true
                mono: true
                dim: rowItem.size <= 0
                text: rowItem.size > 0 ? Format.size(rowItem.size) : "—"
            }

            // The bar and the percentage
            RowLayout {
                Layout.preferredWidth: page.cw("progress") - 16
                Layout.minimumWidth: page.cw("progress") - 16
                Layout.maximumWidth: page.cw("progress") - 16
                Layout.leftMargin: 16
                Layout.fillHeight: true
                spacing: 10
                UiProgress {
                    objectName: "rowProgress"
                    Layout.fillWidth: true
                    value: rowItem.progress
                    color: rowItem.stateColor
                    active: TorrentStatus.isActive(rowItem.state)
                }
                CellText {
                    fixedWidth: 36
                    horizontalAlignment: Text.AlignRight
                    mono: true
                    text: Math.floor(rowItem.progress * 100) + "%"
                    color: Theme.textDim
                }
            }

            // ↓ download over ↑ upload
            ColumnLayout {
                objectName: "cell_speed"
                Layout.preferredWidth: page.cw("speed") - 12
                Layout.minimumWidth: page.cw("speed") - 12
                Layout.maximumWidth: page.cw("speed") - 12
                Layout.rightMargin: 12
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                FigureLine {
                    value: rowItem.dlSpeed
                    text: "↓ " + (rowItem.dlSpeed > 0 ? Format.speed(rowItem.dlSpeed) : "—")
                    color: rowItem.dlSpeed > 0 ? Theme.download : Theme.textFaint
                }
                FigureLine {
                    value: rowItem.upSpeed
                    text: "↑ " + (rowItem.upSpeed > 0 ? Format.speed(rowItem.upSpeed) : "—")
                    color: rowItem.upSpeed > 0 ? Theme.upload : Theme.textFaint
                }
            }

            CellText {
                visible: page.colVisible("eta")
                fixedWidth: page.cw("eta") - 12
                alignRight: true
                mono: true
                // only a running download has an estimate; ∞ when it is running without one
                readonly property bool running: rowItem.state === "downloading" || rowItem.state === "stalledDl"
                                                || rowItem.state === "metadata"
                dim: !running || rowItem.eta >= 8640000
                text: running ? Format.eta(rowItem.eta) : "—"
            }

            // connected seeds / peers; the whole swarm on hover
            CellText {
                id: swarmCell
                objectName: "cell_swarm"
                visible: page.colVisible("swarm")
                fixedWidth: page.cw("swarm") - 12
                alignRight: true
                mono: true
                dim: rowItem.seeds === 0 && rowItem.peers === 0
                text: rowItem.seeds + " / " + rowItem.peers

                HoverHandler { id: swarmHover }
                UiTooltip {
                    text: qsTr("Seeds: %1 of %2 · peers: %3 of %4")
                          .arg(rowItem.seeds).arg(rowItem.seedsTotal).arg(rowItem.peers).arg(rowItem.peersTotal)
                    shown: swarmHover.hovered
                }
            }

            CellText {
                visible: page.colVisible("ratio")
                fixedWidth: page.cw("ratio") - 12
                alignRight: true
                mono: true
                color: rowItem.ratio >= 1 ? Theme.goodRatio : Theme.text
                text: Format.ratio(rowItem.ratio)
            }

            Item {
                Layout.preferredWidth: 36
                Layout.fillHeight: true
                UiButton {
                    anchors.centerIn: parent
                    size: "iconSm"
                    variant: "ghost"
                    iconPath: Icons.more
                    focusPolicy: Qt.NoFocus
                    opacity: hover.hovered || rowItem.selected ? 1 : 0
                    Behavior on opacity {
                        enabled: !Theme.reducedMotion
                        NumberAnimation { duration: Theme.durFast }
                    }
                    Accessible.name: qsTr("Actions for %1").arg(rowItem.name)
                    onClicked: {
                        if (!rowItem.selected)
                            page.selectOnly(rowItem.torrentId)
                        rowMenu.popup()
                    }
                }
            }
        }
    }

    // --- Menus and dialogs ------------------------------------------------------------------------
    UiMenu {
        id: rowMenu
        objectName: "transfersRowMenu"

        UiMenuItem { text: qsTr("Start"); iconPath: Icons.play; onTriggered: TorrentListModel.start(page.targetIds()) }
        UiMenuItem { text: qsTr("Stop"); iconPath: Icons.pause; onTriggered: TorrentListModel.stop(page.targetIds()) }
        UiMenuItem { text: qsTr("Force start"); iconPath: Icons.bolt; onTriggered: TorrentListModel.forceStart(page.targetIds()) }
        UiMenuSeparator {}
        UiMenuItem {
            id: watchItem
            readonly property string videoKey: rowMenu.visible ? MediaLibraryModel.bestVideoOf(page.currentId) : ""
            visible: videoKey !== ""
            height: visible ? implicitHeight : 0
            text: qsTr("Watch")
            iconPath: Icons.play
            onTriggered: page.playRequested(videoKey)
        }
        UiMenuItem { text: qsTr("Open folder"); iconPath: Icons.folder; onTriggered: TorrentListModel.openFolder(page.currentId) }
        UiMenuItem { text: qsTr("Copy magnet link"); iconPath: Icons.magnet; onTriggered: TorrentListModel.copyMagnets(page.targetIds()) }
        UiMenuSeparator {}
        UiMenuItem { text: qsTr("Force recheck"); iconPath: Icons.refresh; onTriggered: TorrentListModel.recheck(page.targetIds()) }
        UiMenuItem { text: qsTr("Force reannounce"); iconPath: Icons.network; onTriggered: TorrentListModel.reannounce(page.targetIds()) }
        UiMenuItem { text: qsTr("Move up in queue"); iconPath: Icons.up; onTriggered: TorrentListModel.queueUp(page.targetIds()) }
        UiMenuItem { text: qsTr("Move down in queue"); iconPath: Icons.down; onTriggered: TorrentListModel.queueDown(page.targetIds()) }
        UiMenuSeparator {}
        UiMenuItem {
            text: qsTr("Remove…")
            iconPath: Icons.trash
            shortcut: "Del"
            destructive: true
            onTriggered: removeDialog.ask(page.targetIds())
        }
    }

    UiDialog {
        id: removeDialog
        objectName: "removeDialog"

        property var ids: []

        function ask(list) {
            if (list.length === 0)
                return
            ids = list
            deleteFiles.checked = false
            open()
        }

        title: ids.length === 1
               ? qsTr("Remove “%1”?").arg(TorrentListModel.get(ids[0]).name ?? "")
               : qsTr("Remove %n torrent(s)?", "", ids.length)
        description: qsTr("The torrent leaves the list. Downloaded files stay on disk unless you choose to delete them.")

        RowLayout {
            spacing: Theme.sp(2)
            UiCheckBox {
                id: deleteFiles
                Accessible.name: deleteFilesLabel.text
            }
            Text {
                id: deleteFilesLabel
                text: qsTr("Also delete the downloaded files")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                TapHandler { onTapped: deleteFiles.toggle() }
            }
        }

        footerItems: [
            UiButton {
                variant: "outline"
                text: qsTr("Cancel")
                onClicked: removeDialog.close()
            },
            UiButton {
                objectName: "removeConfirm"
                variant: "destructive"
                text: deleteFiles.checked ? qsTr("Remove and delete files") : qsTr("Remove")
                onClicked: {
                    TorrentListModel.remove(removeDialog.ids, deleteFiles.checked)
                    removeDialog.close()
                    page.clearSelection()
                }
            }
        ]
    }

    UiDialog {
        id: addLinkDialog
        objectName: "addLinkDialog"
        title: qsTr("Add magnet link")
        description: qsTr("Paste a magnet link or an info hash. The torrent starts with your default settings.")

        property string error: ""
        onOpened: {
            error = ""
            linkInput.text = ""
            linkInput.field.forceActiveFocus()
        }

        // the link opens in the Add torrent dialog, which fetches its file list
        function submit() {
            const link = linkInput.text.trim()
            if (link === "")
                return
            close()
            addDialog.show(link)
        }

        UiInput {
            id: linkInput
            Layout.fillWidth: true
            implicitHeight: 36
            placeholderText: "magnet:?xt=urn:btih:…"
            onAccepted: addLinkDialog.submit()
        }
        Text {
            visible: addLinkDialog.error !== ""
            Layout.fillWidth: true
            text: addLinkDialog.error
            color: Theme.error
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            wrapMode: Text.Wrap
        }

        footerItems: [
            UiButton {
                variant: "outline"
                text: qsTr("Cancel")
                onClicked: addLinkDialog.close()
            },
            UiButton {
                text: qsTr("Add")
                enabled: linkInput.text.trim() !== ""
                onClicked: addLinkDialog.submit()
            }
        ]
    }

    FileDialog {
        id: fileDialog
        title: qsTr("Add torrent files")
        fileMode: FileDialog.OpenFiles
        nameFilters: [qsTr("Torrent files (*.torrent)"), qsTr("All files (*)")]
        onAccepted: page.addSources(selectedFiles)
    }

    // Watch a torrent's main video in the built-in player (Main handles it)
    signal playRequested(string key)
    // a torrent was added to watch without downloading: play it once it is in the library
    signal watchRequested(string torrentId, int fileIndex)

    // The add dialog for a link or file; `watch` starts on "Watch without downloading"
    function openSource(source, watch) {
        addDialog.show(source, watch)
    }

    function openAddFile() {
        fileDialog.open()
    }
    function openAddLink() {
        addLinkDialog.open()
    }

    // The command palette picked a torrent: select it, scroll to it, show its details
    Connections {
        target: TransfersState
        function onFocusIdChanged() {
            const id = TransfersState.focusId
            if (id === "")
                return
            const row = filter.rowOf(id)
            if (row >= 0) {
                page.selectOnly(id)
                list.positionViewAtIndex(row, ListView.Center)
                list.forceActiveFocus()
            }
            TransfersState.focusId = ""
        }
    }

    // One torrent opens the Add torrent dialog; several are added at once with the defaults
    function addSources(urls) {
        const list = Array.from(urls).map(u => String(u))
        if (list.length === 1) {
            addDialog.show(list[0])
            return
        }
        let added = 0
        for (const url of list) {
            const error = url.toLowerCase().endsWith(".torrent") ? TorrentListModel.addFile(url) : TorrentListModel.addLink(url)
            if (error === "")
                ++added
        }
        toast.show(qsTr("Added %n torrent(s)", "", added), added === 0)
    }

    AddTorrentDialog {
        id: addDialog
        Component.onCompleted: {
            const demo = TorrentListModel.demoAddState()
            if (demo.name !== undefined) {
                draft.loadDemo(demo)
                open()
            }
        }
        onTorrentAdded: name => toast.show(qsTr("Added “%1”").arg(name), false)
        onWatchRequested: (id, file) => page.watchRequested(id, file)
    }

    UiToast {
        id: toast
        objectName: "transfersToast"
    }
}
