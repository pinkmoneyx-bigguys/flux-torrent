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
    // Fixed widths; Name takes the rest. Less important columns drop out on narrow windows.
    readonly property real tableWidth: table.width
    function colVisible(key) {
        switch (key) {
        case "up": return tableWidth >= 880
        case "eta": return tableWidth >= 950
        case "ratio": return tableWidth >= 1020
        default: return true
        }
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

        PageHeader {
            Layout.fillWidth: true
            title: page.title
            subtitle: TransfersState.status === "all" ? "" : TransfersState.label(TransfersState.status)

            UiButton {
                objectName: "addLinkButton"
                variant: "outline"
                iconPath: Icons.link
                text: qsTr("Add link")
                onClicked: addLinkDialog.open()
            }
            UiButton {
                objectName: "addTorrentButton"
                iconPath: Icons.plus
                text: qsTr("Add torrent")
                onClicked: fileDialog.open()
            }
        }

        // Toolbar: filter on the left, selection actions or the row count on the right
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            Layout.bottomMargin: Theme.sp(3)
            spacing: Theme.sp(2)

            UiInput {
                id: searchInput
                objectName: "transfersSearch"
                Layout.preferredWidth: 280
                iconPath: Icons.filter
                placeholderText: qsTr("Filter torrents…")
                field.Keys.onDownPressed: list.forceActiveFocus()
            }

            Item { Layout.fillWidth: true }

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
            id: tableFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.bottomMargin: details.visible ? 0 : Theme.sp(6)
            radius: Theme.radiusCtl + 2
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            clip: true

            Item {
                id: table
                anchors.fill: parent
                anchors.margins: 1

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
            readonly property real openHeight: Math.max(220, Math.min(320, page.height * 0.36))
            Layout.fillWidth: true
            Layout.preferredHeight: open ? openHeight : 0
            Behavior on Layout.preferredHeight {
                enabled: !Theme.reducedMotion
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
    // The header and row share one cell layout: same widths and spacing, so columns line up
    component Cells: RowLayout {
        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 4
    }

    component HeaderCell: AbstractButton {
        id: hc
        property string sortKey
        property bool alignRight: false
        readonly property bool sorted: sortKey !== "" && filter.sortKey === sortKey

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
                path: filter.descending ? Icons.chevronDown : Icons.chevronUp
                size: 14
                strokeWidth: 2
                color: Theme.text
            }
            Item { Layout.fillWidth: hc.alignRight }
        }
    }

    component TableHeader: Rectangle {
        height: 40
        color: Theme.glass ? Qt.rgba(1, 1, 1, 0.04) : "#141414"

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
            HeaderCell { text: qsTr("Name"); sortKey: "name"; Layout.fillWidth: true; Layout.minimumWidth: 120 }
            HeaderCell { text: qsTr("Size"); sortKey: "size"; alignRight: true; Layout.preferredWidth: 88 }
            // the status glyph sits in the progress cell; the header text lines up with the bar
            HeaderCell { text: qsTr("Progress"); sortKey: "progress"; Layout.preferredWidth: 240; Layout.leftMargin: 30 }
            HeaderCell { text: qsTr("Down"); sortKey: "dlSpeed"; alignRight: true; Layout.preferredWidth: 96 }
            HeaderCell { text: qsTr("Up"); sortKey: "upSpeed"; alignRight: true; Layout.preferredWidth: 96; visible: page.colVisible("up") }
            HeaderCell { text: qsTr("ETA"); sortKey: "eta"; alignRight: true; Layout.preferredWidth: 84; visible: page.colVisible("eta") }
            HeaderCell { text: qsTr("Ratio"); sortKey: "ratio"; alignRight: true; Layout.preferredWidth: 64; visible: page.colVisible("ratio") }
            Item { Layout.preferredWidth: 36 }
        }
    }

    component CellText: Text {
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

    // The torrent's state as a tinted glyph; its name shows on hover. Checking spins.
    component StatusGlyph: Rectangle {
        id: glyph
        property string torrentState
        readonly property color tint: TorrentStatus.color(torrentState)

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: 22
        implicitHeight: 22
        radius: 11
        color: Theme.alpha(tint, 0.14)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durMed }
        }

        Accessible.role: Accessible.StaticText
        Accessible.name: TorrentStatus.label(torrentState)

        Icon {
            id: glyphIcon
            anchors.centerIn: parent
            path: TorrentStatus.icon(glyph.torrentState)
            size: 13
            strokeWidth: 2.25
            color: glyph.tint
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durMed }
            }
            RotationAnimation on rotation {
                running: glyph.torrentState === "checking" && glyph.visible && !Theme.reducedMotion
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                onRunningChanged: if (!running) glyphIcon.rotation = 0
            }
        }

        HoverHandler { id: glyphHover }
        UiTooltip {
            text: TorrentStatus.label(glyph.torrentState)
            shown: glyphHover.hovered
        }
    }

    component TorrentRowDelegate: Rectangle {
        id: rowItem

        required property int index
        required property string torrentId
        required property string name
        required property string state
        required property real size
        required property real progress
        required property real dlSpeed
        required property real upSpeed
        required property real eta
        required property real ratio
        required property string category

        readonly property bool selected: page.isSelected(torrentId)
        readonly property bool focused: page.currentId === torrentId

        height: 40
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
            CellText {
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.rightMargin: 12
                text: rowItem.name
                font.weight: Font.Medium
            }
            CellText {
                Layout.preferredWidth: 88
                alignRight: true
                dim: rowItem.size <= 0
                text: rowItem.size > 0 ? Format.size(rowItem.size) : "—"
            }
            // Status glyph, then the bar and the percentage
            RowLayout {
                Layout.preferredWidth: 240
                Layout.maximumWidth: 240
                Layout.fillHeight: true
                spacing: Theme.sp(2)
                StatusGlyph {
                    objectName: "statusGlyph"
                    torrentState: rowItem.state
                }
                UiProgress {
                    objectName: "rowProgress"
                    Layout.fillWidth: true
                    value: rowItem.progress
                    color: TorrentStatus.color(rowItem.state)
                    active: TorrentStatus.isActive(rowItem.state)
                }
                CellText {
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                    text: Math.floor(rowItem.progress * 1000) / 10 + "%"
                    color: Theme.textDim
                    font.pixelSize: Theme.textXs
                }
            }
            CellText {
                Layout.preferredWidth: 96
                alignRight: true
                dim: rowItem.dlSpeed === 0
                text: Format.speed(rowItem.dlSpeed)
            }
            CellText {
                visible: page.colVisible("up")
                Layout.preferredWidth: 96
                alignRight: true
                dim: rowItem.upSpeed === 0
                text: Format.speed(rowItem.upSpeed)
            }
            CellText {
                visible: page.colVisible("eta")
                Layout.preferredWidth: 84
                alignRight: true
                // only a running download has an estimate; ∞ when it is running without one
                readonly property bool running: rowItem.state === "downloading" || rowItem.state === "stalledDl"
                                                || rowItem.state === "metadata"
                dim: !running || rowItem.eta >= 8640000
                text: running ? Format.eta(rowItem.eta) : "—"
            }
            CellText {
                visible: page.colVisible("ratio")
                Layout.preferredWidth: 64
                alignRight: true
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
    }

    UiToast {
        id: toast
        objectName: "transfersToast"
    }
}
