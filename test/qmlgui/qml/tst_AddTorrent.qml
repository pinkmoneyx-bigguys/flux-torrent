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
    Connections {
        target: dialog
        function onTorrentAdded(name) { tc.addedName = name }
    }

    function init() {
        addedName = ""
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
