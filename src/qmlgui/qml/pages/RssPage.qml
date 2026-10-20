import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// RSS feeds, laid out like the shadcn Mail example: feeds | articles | reader in one bordered frame.
// Feeds can be added, grouped in folders, renamed and removed; articles are read, opened or downloaded;
// the auto-download rules live in their own dialog.
Surface {
    id: page
    objectName: "page_rss"

    property string title: qsTr("RSS feeds")
    property string hint: qsTr("Follow feeds and download new episodes automatically.")

    kind: Theme.glass ? "panel" : "chrome"
    radius: Theme.radiusPanel

    // The article in the reader (row of RssManager.articles), -1 for none
    property int currentArticle: -1
    readonly property var article: currentArticle >= 0 && articleList.currentItem ? articleList.currentItem.info : null

    function selectArticle(row) {
        currentArticle = row
        articleList.currentIndex = row
        if (row >= 0)
            RssManager.markRead(row)
    }

    Connections {
        target: RssManager.articles
        function onModelReset() {
            page.currentArticle = -1
            articleList.currentIndex = -1
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PageHeader {
            Layout.fillWidth: true
            title: page.title

            UiButton {
                objectName: "rssRulesButton"
                variant: "outline"
                iconPath: Icons.bolt
                text: RssManager.rules.length > 0 ? qsTr("Auto-download · %1").arg(RssManager.rules.length) : qsTr("Auto-download")
                onClicked: rulesDialog.open()
            }
            UiButton {
                variant: "outline"
                size: "icon"
                iconPath: Icons.refresh
                Accessible.name: qsTr("Refresh all feeds")
                onClicked: RssManager.refresh("")
            }
            UiButton {
                objectName: "rssAddFeedButton"
                iconPath: Icons.plus
                text: qsTr("Add feed")
                onClicked: addFeedDialog.ask()
            }
        }

        // shadcn Alert: RSS processing is off in a fresh qBittorrent profile
        Rectangle {
            objectName: "rssOffAlert"
            visible: !RssManager.processingEnabled
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp(6)
            Layout.rightMargin: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            implicitHeight: alertRow.implicitHeight + 24
            radius: Theme.radiusCtl + 2
            color: "transparent"
            border.width: 1
            border.color: Theme.border

            RowLayout {
                id: alertRow
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 16
                spacing: Theme.sp(3)

                Icon {
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 2
                    path: Icons.clock
                    size: 16
                    strokeWidth: 2
                    color: Theme.text
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: qsTr("Feed updates are off")
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        font.weight: Font.Medium
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Flux does not check your feeds for new articles, and auto-download rules do not run.")
                        color: Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        wrapMode: Text.Wrap
                    }
                }
                UiButton {
                    objectName: "rssTurnOn"
                    variant: "secondary"
                    text: qsTr("Turn on")
                    onClicked: RssManager.processingEnabled = true
                }
            }
        }

        // --- Three panes --------------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Theme.sp(6)
            Layout.topMargin: Theme.sp(4)
            radius: Theme.radiusCtl + 2
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                // Feeds ---------------------------------------------------------------------------
                ColumnLayout {
                    // a nested layout fills the width by default: pin the column instead
                    Layout.fillWidth: false
                    Layout.preferredWidth: 248
                    Layout.fillHeight: true
                    spacing: 0

                    PaneHeader {
                        title: qsTr("Feeds")
                        UiButton {
                            size: "iconSm"
                            variant: "ghost"
                            iconPath: Icons.folder
                            Accessible.name: qsTr("New folder")
                            onClicked: folderDialog.ask()
                        }
                    }
                    ListView {
                        id: feedList
                        objectName: "rssFeedList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        topMargin: 6
                        bottomMargin: 6
                        ScrollBar.vertical: ScrollBar {}
                        model: [{ path: "", name: qsTr("All feeds"), folder: false, depth: 0, unread: RssManager.unreadCount, all: true }]
                               .concat(RssManager.feeds)
                        delegate: FeedRow {}
                    }
                }

                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.border }

                // Articles ------------------------------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: Math.min(420, Math.max(320, parent.width * 0.34))
                    Layout.fillHeight: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        spacing: Theme.sp(2)

                        UiInput {
                            objectName: "rssSearch"
                            Layout.fillWidth: true
                            iconPath: Icons.search
                            placeholderText: qsTr("Search articles…")
                            onTextChanged: RssManager.search = text
                        }
                        UiTabs {
                            objectName: "rssReadFilter"
                            currentKey: RssManager.unreadOnly ? "unread" : "all"
                            model: [{ key: "all", label: qsTr("All") }, { key: "unread", label: qsTr("Unread") }]
                            onActivated: key => RssManager.unreadOnly = key === "unread"
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

                    ListView {
                        id: articleList
                        objectName: "rssArticleList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: RssManager.articles
                        currentIndex: -1
                        spacing: 8
                        topMargin: 12
                        bottomMargin: 12
                        leftMargin: 12
                        rightMargin: 12
                        keyNavigationEnabled: true
                        activeFocusOnTab: true
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ArticleCard {}
                        Keys.onUpPressed: page.selectArticle(Math.max(0, currentIndex - 1))
                        Keys.onDownPressed: page.selectArticle(Math.min(count - 1, currentIndex + 1))

                        Text {
                            visible: articleList.count === 0
                            anchors.centerIn: parent
                            width: parent.width - 48
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: RssManager.feeds.length === 0 ? qsTr("Add a feed to see its articles here.")
                                : RssManager.search !== "" || RssManager.unreadOnly ? qsTr("No articles match.")
                                : qsTr("No articles yet.")
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                        }
                    }
                }

                Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.border }

                // Reader --------------------------------------------------------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        visible: page.article !== null

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            spacing: Theme.sp(2)

                            UiButton {
                                objectName: "rssDownload"
                                visible: page.article && (page.article.torrentUrl !== "" || page.article.link.indexOf("magnet:") === 0
                                                          || /\.torrent($|\?)/i.test(page.article.link))
                                iconPath: Icons.download
                                text: qsTr("Download torrent")
                                onClicked: {
                                    if (RssManager.download(page.currentArticle))
                                        toast.show(qsTr("Added “%1”").arg(page.article.title), false)
                                    else
                                        toast.show(qsTr("This article has no torrent."), true)
                                }
                            }
                            UiButton {
                                visible: page.article && page.article.link !== ""
                                variant: "outline"
                                iconPath: Icons.externalLink
                                text: qsTr("Open in browser")
                                onClicked: RssManager.openLink(page.currentArticle)
                            }
                            Item { Layout.fillWidth: true }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: readerColumn.implicitHeight + 48
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar {}

                            ColumnLayout {
                                id: readerColumn
                                x: 24
                                y: 20
                                width: parent.width - 48
                                spacing: Theme.sp(3)

                                Text {
                                    objectName: "rssReaderTitle"
                                    Layout.fillWidth: true
                                    text: page.article ? page.article.title : ""
                                    color: Theme.text
                                    font.family: Theme.fontText
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                    Accessible.role: Accessible.Heading
                                    Accessible.name: text
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: page.article
                                          ? [page.article.feedName, page.article.author,
                                             page.article.date && !isNaN(page.article.date)
                                                 ? page.article.date.toLocaleString(Qt.locale(), Locale.ShortFormat) : ""]
                                                .filter(s => s && s !== "").join("  ·  ")
                                          : ""
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textSm
                                    wrapMode: Text.Wrap
                                }
                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                                TextEdit {
                                    Layout.fillWidth: true
                                    readOnly: true
                                    selectByMouse: true
                                    textFormat: TextEdit.RichText
                                    wrapMode: TextEdit.Wrap
                                    text: page.article ? (page.article.description || qsTr("This article has no description.")) : ""
                                    color: Theme.text
                                    selectionColor: "#3F3F46"
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textBase
                                    onLinkActivated: link => {
                                        if (/^https?:/i.test(link))
                                            Qt.openUrlExternally(link)
                                    }
                                    HoverHandler {
                                        cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: page.article === null
                        anchors.centerIn: parent
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
                                path: Icons.rss
                                size: 20
                                strokeWidth: 1.75
                                color: Theme.text
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: RssManager.feeds.length === 0 ? qsTr("No feeds yet") : qsTr("No article selected")
                            color: Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: 16
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 320
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: RssManager.feeds.length === 0
                                  ? qsTr("Add the RSS address of a tracker or a show to follow its new releases.")
                                  : qsTr("Pick an article on the left to read it here.")
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                        }
                        UiButton {
                            visible: RssManager.feeds.length === 0
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.sp(3)
                            iconPath: Icons.plus
                            text: qsTr("Add feed")
                            onClicked: addFeedDialog.ask()
                        }
                    }
                }
            }
        }
    }

    // --- Pieces ---------------------------------------------------------------------------------
    component PaneHeader: RowLayout {
        property string title
        default property alias actions: actionRow.data
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        Layout.leftMargin: 16
        Layout.rightMargin: 10
        spacing: Theme.sp(2)
        Text {
            Layout.fillWidth: true
            text: parent.title
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            font.weight: Font.Medium
        }
        RowLayout {
            id: actionRow
            spacing: 2
        }
    }

    component FeedRow: AbstractButton {
        id: fr
        required property var modelData
        readonly property bool current: RssManager.selectedPath === modelData.path

        width: ListView.view.width
        height: 32
        leftPadding: 16 + (modelData.depth ?? 0) * 14
        rightPadding: 14
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        text: modelData.name

        Accessible.role: Accessible.ListItem
        Accessible.name: text
        Accessible.selected: current

        onClicked: RssManager.selectedPath = modelData.path

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: {
                if (fr.modelData.all)
                    return
                feedMenu.path = fr.modelData.path
                feedMenu.name = fr.modelData.name
                feedMenu.folder = fr.modelData.folder
                feedMenu.popup()
            }
        }

        background: Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: Theme.radiusCtl - 2
            color: fr.current ? Theme.selected : fr.hovered ? Theme.hover : Theme.alpha(Theme.hover, 0)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
            border.width: fr.visualFocus ? 2 : 0
            border.color: Theme.ring
        }
        contentItem: RowLayout {
            spacing: Theme.sp(2)
            Icon {
                path: fr.modelData.all ? Icons.inbox : fr.modelData.folder ? Icons.folder : Icons.rss
                size: 15
                strokeWidth: 1.75
                color: fr.current ? Theme.text : Theme.textDim
            }
            Text {
                Layout.fillWidth: true
                text: fr.text
                color: fr.current ? Theme.text : Theme.alpha(Theme.text, 0.85)
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: fr.current || (fr.modelData.unread ?? 0) > 0 ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
            UiSpinner {
                visible: fr.modelData.loading === true
                size: 13
            }
            Rectangle {
                visible: fr.modelData.error === true && fr.modelData.loading !== true
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.error
            }
            Text {
                visible: (fr.modelData.unread ?? 0) > 0
                text: fr.modelData.unread
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }
    }

    component ArticleCard: AbstractButton {
        id: card
        required property int index
        required property string title
        required property string snippet
        required property string feedName
        required property string author
        required property string description
        required property string torrentUrl
        required property string link
        required property var date
        required property bool read
        readonly property bool current: ListView.isCurrentItem
        // what the reader shows for the current card
        readonly property var info: ({ title: title, feedName: feedName, author: author, description: description,
                                       torrentUrl: torrentUrl, link: link, date: date })

        width: ListView.view.width - 24
        padding: 12
        hoverEnabled: true
        focusPolicy: Qt.NoFocus

        Accessible.role: Accessible.ListItem
        Accessible.name: title
        Accessible.selected: current

        onClicked: {
            articleList.forceActiveFocus()
            page.selectArticle(index)
        }
        onDoubleClicked: RssManager.openLink(index)

        background: Rectangle {
            radius: Theme.radiusCtl + 2
            color: card.current ? Theme.muted : card.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
            Behavior on color {
                enabled: !Theme.reducedMotion
                ColorAnimation { duration: Theme.durFast }
            }
            border.width: 1
            border.color: Theme.border
        }
        contentItem: ColumnLayout {
            id: cardColumn
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(2)
                Rectangle {
                    visible: !card.read
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: Theme.download
                }
                Text {
                    Layout.fillWidth: true
                    text: card.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.weight: card.read ? Font.Normal : Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.alignment: Qt.AlignTop
                    text: card.date && !isNaN(card.date) ? page.ago(card.date) : ""
                    color: card.current ? Theme.text : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                }
            }
            Text {
                visible: card.snippet !== ""
                Layout.fillWidth: true
                text: card.snippet
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs + 1
                lineHeight: 1.25
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 6
                UiBadge {
                    text: card.feedName
                    variant: "secondary"
                    implicitHeight: 20
                }
                UiBadge {
                    visible: card.torrentUrl !== "" || card.link.indexOf("magnet:") === 0
                    text: qsTr("torrent")
                    implicitHeight: 20
                }
            }
        }
    }

    // "5 min ago", "3 h ago", "2 d ago", then the date
    function ago(date) {
        const secs = Math.max(0, (Date.now() - date.getTime()) / 1000)
        if (secs < 60)
            return qsTr("now")
        if (secs < 3600)
            return qsTr("%1 min").arg(Math.floor(secs / 60))
        if (secs < 86400)
            return qsTr("%1 h").arg(Math.floor(secs / 3600))
        if (secs < 7 * 86400)
            return qsTr("%1 d").arg(Math.floor(secs / 86400))
        return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    // --- Menus and dialogs ------------------------------------------------------------------------
    UiMenu {
        id: feedMenu
        property string path
        property string name
        property bool folder
        UiMenuItem { text: qsTr("Refresh"); iconPath: Icons.refresh; onTriggered: RssManager.refresh(feedMenu.path) }
        UiMenuItem { text: qsTr("Mark all as read"); iconPath: Icons.check; onTriggered: RssManager.markAllRead(feedMenu.path) }
        UiMenuSeparator {}
        UiMenuItem { text: qsTr("Rename…"); onTriggered: renameDialog.ask(feedMenu.path, feedMenu.name) }
        UiMenuItem {
            text: qsTr("Remove…")
            iconPath: Icons.trash
            destructive: true
            onTriggered: removeDialog.ask(feedMenu.path, feedMenu.name, feedMenu.folder)
        }
    }

    UiDialog {
        id: addFeedDialog
        objectName: "rssAddFeedDialog"
        property string error
        property string folder: ""
        function ask() {
            error = ""
            urlInput.text = ""
            folder = ""
            open()
            urlInput.field.forceActiveFocus()
        }
        function submit() {
            error = RssManager.addFeed(urlInput.text, folder)
            if (error === "")
                close()
        }
        title: qsTr("Add feed")
        description: qsTr("Paste the RSS or Atom address. Trackers usually list it next to a search or on your profile page.")

        UiInput {
            id: urlInput
            Layout.fillWidth: true
            implicitHeight: 36
            iconPath: Icons.link
            placeholderText: "https://…/rss"
            onAccepted: addFeedDialog.submit()
        }
        RowLayout {
            visible: RssManager.feeds.some(f => f.folder)
            spacing: Theme.sp(3)
            Text {
                text: qsTr("Folder")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
            }
            UiSelect {
                Layout.preferredWidth: 220
                text: qsTr("Folder")
                currentKey: addFeedDialog.folder
                model: [{ key: "", label: qsTr("No folder") }]
                       .concat(RssManager.feeds.filter(f => f.folder).map(f => ({ key: f.path, label: f.path.replace(/\\/g, " / ") })))
                onActivated: key => addFeedDialog.folder = key
            }
        }
        ErrorText { text: addFeedDialog.error }

        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Cancel"); onClicked: addFeedDialog.close() },
            UiButton { text: qsTr("Add"); enabled: urlInput.text.trim() !== ""; onClicked: addFeedDialog.submit() }
        ]
    }

    UiDialog {
        id: folderDialog
        property string error
        function ask() {
            error = ""
            folderInput.text = ""
            open()
            folderInput.field.forceActiveFocus()
        }
        function submit() {
            error = RssManager.addFolder(folderInput.text)
            if (error === "")
                close()
        }
        title: qsTr("New folder")
        description: qsTr("Folders group feeds; a folder shows the articles of all its feeds.")
        UiInput {
            id: folderInput
            Layout.fillWidth: true
            implicitHeight: 36
            placeholderText: qsTr("Folder name")
            onAccepted: folderDialog.submit()
        }
        ErrorText { text: folderDialog.error }
        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Cancel"); onClicked: folderDialog.close() },
            UiButton { text: qsTr("Create"); enabled: folderInput.text.trim() !== ""; onClicked: folderDialog.submit() }
        ]
    }

    UiDialog {
        id: renameDialog
        property string path
        property string error
        function ask(itemPath, name) {
            path = itemPath
            error = ""
            renameInput.text = name
            open()
            renameInput.field.forceActiveFocus()
            renameInput.field.selectAll()
        }
        function submit() {
            error = RssManager.rename(path, renameInput.text)
            if (error === "")
                close()
        }
        title: qsTr("Rename")
        UiInput {
            id: renameInput
            Layout.fillWidth: true
            implicitHeight: 36
            onAccepted: renameDialog.submit()
        }
        ErrorText { text: renameDialog.error }
        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Cancel"); onClicked: renameDialog.close() },
            UiButton { text: qsTr("Rename"); enabled: renameInput.text.trim() !== ""; onClicked: renameDialog.submit() }
        ]
    }

    UiDialog {
        id: removeDialog
        property string path
        function ask(itemPath, name, isFolder) {
            path = itemPath
            title = isFolder ? qsTr("Remove the folder “%1”?").arg(name) : qsTr("Remove the feed “%1”?").arg(name)
            description = isFolder ? qsTr("The folder and every feed in it are removed with their articles.")
                                   : qsTr("The feed and its downloaded articles are removed. Torrents you added stay.")
            open()
        }
        footerItems: [
            UiButton { variant: "outline"; text: qsTr("Cancel"); onClicked: removeDialog.close() },
            UiButton {
                variant: "destructive"
                text: qsTr("Remove")
                onClicked: {
                    const error = RssManager.remove(removeDialog.path)
                    removeDialog.close()
                    if (error !== "")
                        toast.show(error, true)
                }
            }
        ]
    }

    component ErrorText: Text {
        visible: text !== ""
        Layout.fillWidth: true
        color: Theme.error
        font.family: Theme.fontText
        font.pixelSize: Theme.textSm
        wrapMode: Text.Wrap
    }

    RulesDialog {
        id: rulesDialog
    }

    UiToast {
        id: toast
    }
}
