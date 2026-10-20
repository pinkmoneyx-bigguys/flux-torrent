import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Ctrl+K command palette (shadcn Command / cmdk): a query field over grouped results — matching
// torrents, actions and places to go — driven by the keyboard. Picking an entry emits
// triggered(id, arg); the window carries it out.
Popup {
    id: root
    objectName: "commandPalette"

    signal triggered(string id, var arg)

    // Entries of the palette: {group, id, label, icon, shortcut, keywords, arg}
    property var actions: []
    property int current: 0
    readonly property string query: input.text.trim()

    function show() {
        input.text = ""
        current = 0
        open()
    }

    parent: Overlay.overlay
    x: Math.round((parent ? parent.width : 800) / 2 - width / 2)
    y: Math.round((parent ? parent.height : 600) * 0.14)
    width: Math.min(640, (parent ? parent.width : 640) - 48)
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: input.forceActiveFocus()

    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }

    enter: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 }
    }

    background: Rectangle {
        radius: Theme.radiusPanel - 2
        color: Theme.popover
        border.width: 1
        border.color: Theme.border
    }

    // Matching torrents, by name, up to six
    TorrentFilterModel {
        id: torrentMatches
        sourceModel: TorrentListModel
        search: root.query
    }

    function matches(entry, words) {
        const hay = (entry.label + " " + (entry.keywords ?? "")).toLowerCase()
        return words.every(w => hay.indexOf(w) >= 0)
    }

    // Flat rows for the list: group headings and entries (only entries are selectable)
    readonly property var rows: {
        const words = query.toLowerCase().split(" ").filter(w => w !== "")
        const out = []
        let n = 0
        const push = (group, entries) => {
            if (entries.length === 0)
                return
            out.push({ heading: true, label: group })
            for (const e of entries)
                out.push(Object.assign({ heading: false, index: n++ }, e))
        }

        if (words.length > 0) {
            const torrents = []
            for (let i = 0; i < Math.min(6, torrentMatches.count); ++i) {
                const t = TorrentListModel.get(torrentMatches.idAt(i))
                torrents.push({ id: "torrent", label: t.name, icon: Icons.download, arg: t.torrentId,
                                hint: Math.floor(t.progress * 100) + "%" })
            }
            push(qsTr("Torrents"), torrents)
        }

        const groups = []
        for (const a of actions) {
            if (groups.indexOf(a.group) < 0)
                groups.push(a.group)
        }
        for (const g of groups)
            push(g, actions.filter(a => a.group === g && (words.length === 0 || matches(a, words))))

        if (words.length > 0)
            push(qsTr("Search"), [{ id: "searchTrackers", label: qsTr("Search trackers for “%1”").arg(query), icon: Icons.search, arg: query }])
        return out
    }
    readonly property int selectableCount: rows.filter(r => !r.heading).length

    onQueryChanged: current = 0

    function entryAt(index) {
        return rows.find(r => !r.heading && r.index === index)
    }
    function move(delta) {
        if (selectableCount === 0)
            return
        current = (current + delta + selectableCount) % selectableCount
        const row = rows.findIndex(r => !r.heading && r.index === current)
        list.positionViewAtIndex(Math.max(0, row - (delta < 0 ? 1 : 0)), ListView.Contain)
    }
    function activate(index) {
        const e = entryAt(index)
        if (!e)
            return
        close()
        triggered(e.id, e.arg)
    }

    contentItem: ColumnLayout {
        spacing: 0

        // shadcn CommandInput: icon, borderless field, a line under it
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: Theme.sp(2)

            Icon {
                path: Icons.search
                size: 16
                strokeWidth: 2
                color: Theme.textDim
            }
            TextField {
                id: input
                objectName: "commandInput"
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 0
                background: null
                color: Theme.text
                selectionColor: "#3F3F46"
                selectedTextColor: Theme.text
                placeholderText: qsTr("Type a command or search…")
                placeholderTextColor: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textBase
                verticalAlignment: TextInput.AlignVCenter
                Accessible.name: qsTr("Command")
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onReturnPressed: root.activate(root.current)
                Keys.onEnterPressed: root.activate(root.current)
                Keys.onTabPressed: root.move(1)
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

        ListView {
            id: list
            objectName: "commandList"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(360, Math.max(contentHeight, 88))
            Layout.margins: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: row
                required property var modelData
                readonly property bool selected: !modelData.heading && modelData.index === root.current
                width: ListView.view.width
                height: modelData.heading ? 30 : 36

                // CommandGroup heading
                Text {
                    visible: row.modelData.heading
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: row.modelData.label
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    font.weight: Font.Medium
                }

                // CommandItem
                Rectangle {
                    visible: !row.modelData.heading
                    anchors.fill: parent
                    radius: Theme.radiusCtl - 2
                    color: row.selected ? Theme.hover : "transparent"

                    HoverHandler {
                        onHoveredChanged: if (hovered) root.current = row.modelData.index
                    }
                    TapHandler {
                        onTapped: root.activate(row.modelData.index)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: Theme.sp(2)

                        Icon {
                            path: row.modelData.icon ?? ""
                            size: 16
                            strokeWidth: 1.75
                            color: row.selected ? Theme.text : Theme.textDim
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.label ?? ""
                            color: Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: (row.modelData.hint ?? "") !== ""
                            text: row.modelData.hint ?? ""
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            font.features: { "tnum": 1 }
                        }
                        // CommandShortcut
                        Text {
                            visible: (row.modelData.shortcut ?? "") !== ""
                            text: row.modelData.shortcut ?? ""
                            color: Theme.textFaint
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            font.letterSpacing: 1
                        }
                    }
                }
            }

            // CommandEmpty
            Text {
                visible: root.selectableCount === 0
                anchors.centerIn: parent
                text: qsTr("No results found.")
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

        // keyboard hints
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: Theme.sp(4)
            Hint { keys: "↑ ↓"; text: qsTr("to move") }
            Hint { keys: "Enter"; text: qsTr("to choose") }
            Hint { keys: "Esc"; text: qsTr("to close") }
            Item { Layout.fillWidth: true }
        }
    }

    component Hint: RowLayout {
        property string keys
        property string text
        spacing: 6
        Rectangle {
            implicitWidth: keyText.implicitWidth + 10
            implicitHeight: 20
            radius: 4
            color: Theme.muted
            Text {
                id: keyText
                anchors.centerIn: parent
                text: parent.parent.keys
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        Text {
            text: parent.text
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
        }
    }
}
