import QtQuick
import QtTest
import Flux

// The Add torrent dialog over AddTorrentDraft.loadDemo (no session in tests): the file tree with
// folders first, checking folders and files, collapsing, options and accepting.
TestCase {
    id: tc
    name: "AddTorrent"
    when: windowShown
    width: 1200
    height: 860
    visible: true

    readonly property var demo: ({
        name: "Pack",
        files: [
            { path: "Pack/readme.txt", size: 10 },
            { path: "Pack/Movie A/a.mkv", size: 1000 },
            { path: "Pack/Movie A/Subs/a.srt", size: 5 },
            { path: "Pack/Movie B/b.mkv", size: 2000 }
        ],
        categories: ["Movies", "TV"],
        savePath: "D:/Downloads"
    })

    AddTorrentDialog {
        id: dialog
    }

    property string addedName: ""
    property var watched: null
    Connections {
        target: dialog
        function onTorrentAdded(name) { tc.addedName = name }
        function onWatchRequested(id, file) { tc.watched = { id: id, file: file } }
    }

    function init() {
        addedName = ""
        watched = null
        dialog.watchMode = false
        dialog.draft.loadDemo(demo)
        dialog.open()
        tryCompare(dialog, "opened", true)
    }

    function cleanup() {
        dialog.close()
        tryCompare(dialog, "visible", false)
    }

    function rows() {
        return dialog.draft.files
    }

    function rowNamed(name) {
        return rows().find(r => r.name === name)
    }

    // With a video inside: watch without downloading plays the largest video; nothing to choose
    function test_watchWithoutDownloading() {
        verify(dialog.canWatch, "there is a video")
        const tabs = findChild(dialog.contentItem, "addModeTabs")
        verify(tabs.visible)
        compare(dialog.draft.bestVideoFile(), 3, "b.mkv is the largest video")
        dialog.watchMode = true
        verify(findChild(dialog.contentItem, "addWatchInfo").visible, "it says what happens")
        compare(dialog.draft.fileName(3), "b.mkv")
        const watch = findChild(dialog.contentItem, "addWatchConfirm")
        verify(watch.visible && watch.enabled)
        mouseClick(watch)
        verify(tc.watched !== null, "asked to play")
        compare(tc.watched.file, 3)
        tryCompare(dialog, "visible", false)
    }

    function test_noVideoNoWatching() {
        dialog.draft.loadDemo({ name: "Docs", files: [{ path: "Docs/a.pdf", size: 10 }], savePath: "D:/Downloads" })
        verify(!dialog.canWatch)
        verify(!findChild(dialog.contentItem, "addModeTabs").visible, "no choice to make")
    }

    function test_treeFoldersFirst() {
        const names = rows().map(r => r.name)
        compare(names, ["Pack", "Movie A", "Subs", "a.srt", "a.mkv", "Movie B", "b.mkv", "readme.txt"])
        compare(rowNamed("Movie A").size, 1005, "a folder's size is everything under it")
        compare(dialog.draft.wantedCount, 4)
    }

    function test_folderToggle() {
        dialog.draft.toggle(rowNamed("Movie A").row)
        compare(dialog.draft.wantedCount, 2, "unchecking a folder skips its files")
        compare(rowNamed("Pack").state, 1, "the parent shows a partial check")
        compare(dialog.draft.wantedSize, 2010)
        dialog.draft.toggle(rowNamed("Movie A").row)
        compare(dialog.draft.wantedCount, 4)
        compare(rowNamed("Pack").state, 2)
    }

    function test_collapse() {
        dialog.draft.toggleExpanded(rowNamed("Movie A").row)
        verify(!rowNamed("a.mkv"), "a collapsed folder hides its files")
        verify(rowNamed("Movie B"))
        dialog.draft.toggleExpanded(rowNamed("Movie A").row)
        verify(rowNamed("a.mkv"))
    }

    function test_noFilesNoAdd() {
        dialog.draft.setAllWanted(false)
        verify(!findChild(dialog.contentItem, "addTorrentConfirm").enabled)
        compare(dialog.draft.accept() !== "", true)
        dialog.draft.setAllWanted(true)
        verify(findChild(dialog.contentItem, "addTorrentConfirm").enabled)
    }

    function test_categoryAndAccept() {
        dialog.draft.category = "Movies"
        dialog.draft.startNow = false
        mouseClick(findChild(dialog.contentItem, "addTorrentConfirm"))
        compare(addedName, "Pack")
        tryCompare(dialog, "visible", false)
    }

    function test_alreadyAdded() {
        const d = Object.assign({}, demo)
        d.alreadyAdded = true
        dialog.draft.loadDemo(d)
        verify(!findChild(dialog.contentItem, "addTorrentConfirm").enabled)
    }
}
