import QtQuick
import QtTest
import Flux

// "After watching" in the main window: ask (with "don't ask again"), keep, and delete behind an undo toast.
TestCase {
    id: tc
    name: "AfterWatch"
    when: windowShown
    width: 200
    height: 100
    visible: true

    property var main: null

    Component {
        id: mainComponent
        Main {}
    }

    function initTestCase() {
        main = mainComponent.createObject(tc)
        tryVerify(() => main.visible, 3000)
    }

    function cleanupTestCase() {
        main.destroy()
        main = null
    }

    function init() {
        AppSettings.setValue("afterWatching", "ask")
        TorrentListModel.setRows([{ id: "t1", name: "Sintel", state: "seeding", progress: 1 }])
        main.pendingDeleteId = ""
    }

    function cleanup() {
        const dialog = findChild(main.contentItem, "afterWatchDialog")
        if (dialog && dialog.visible) {
            dialog.close()
            tryCompare(dialog, "visible", false)
        }
    }

    function dialog() {
        return findChild(main.contentItem, "afterWatchDialog")
    }

    function test_notWatchedToEndDoesNothing() {
        main.afterPlayback(false)
        verify(!dialog().visible)
    }

    function test_asks() {
        main.afterPlayback(true)
        tryCompare(dialog(), "opened", true)
    }

    function test_keepSilently() {
        AppSettings.setValue("afterWatching", "keep")
        main.afterPlayback(true)
        verify(!dialog().visible)
        compare(main.pendingDeleteId, "")
    }

    function test_deleteWaitsBehindUndo() {
        AppSettings.setValue("afterWatching", "delete")
        main.playerView.torrentId = "t1"
        main.afterPlayback(true)
        compare(main.pendingDeleteId, "t1", "deletion is pending, not done")
        const toast = findChild(main.contentItem, "windowToast")
        tryVerify(() => toast.opacity > 0.99, 1000, "the undo toast is up")
        compare(toast.actionText.length > 0, true)
        mouseClick(findChild(toast, "toastAction"))
        compare(main.pendingDeleteId, "", "undo cancels it")
    }

    function test_dontAskAgainRemembers() {
        main.playerView.torrentId = "t1"
        main.afterPlayback(true)
        tryCompare(dialog(), "opened", true)
        mouseClick(findChild(dialog().contentItem, "afterWatchDontAsk"))
        mouseClick(findChild(dialog().contentItem, "afterWatchDelete"))
        compare(AppSettings.value("afterWatching"), "delete")
        compare(main.pendingDeleteId, "t1")
        main.pendingDeleteId = ""
    }
}
