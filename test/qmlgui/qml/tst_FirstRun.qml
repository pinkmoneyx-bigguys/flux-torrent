import QtQuick
import QtTest
import Flux

// The first-run dialog: what it shows for the qBittorrent profile it was given, that "Migrate" is blocked
// while qBittorrent runs, and the signals the C++ side listens to.
TestCase {
    id: tc
    name: "FirstRun"
    when: windowShown
    width: 200
    height: 100
    visible: true

    property var dlg: null

    Component {
        id: dialogComponent
        FirstRunWindow {
            visible: false
        }
    }

    Component {
        id: spyComponent
        SignalSpy {}
    }

    function init() {
        FluxTestI18n.setLanguage("")
        dlg = dialogComponent.createObject(tc)
        verify(dlg, "FirstRunWindow.qml loads")
    }

    function cleanup() {
        if (dlg)
            dlg.destroy()
        dlg = null
        FluxTestI18n.setLanguage("")
    }

    function text(name) {
        const item = findChild(dlg.contentItem, name)
        verify(item, name + " exists")
        return item
    }

    function signalSpy(target, signalName) {
        const spy = createTemporaryObject(spyComponent, tc, { target: target, signalName: signalName })
        verify(spy.valid, "spy for " + signalName)
        return spy
    }

    function test_defaults() {
        verify(dlg.migrateButton.enabled, "Migrate is available")
        verify(dlg.startFreshButton.enabled, "Start fresh is available")
        verify(!text("runningNote").visible, "no hint while qBittorrent is closed")
        verify(!text("errorText").visible, "no error before the first attempt")
        compare(dlg.migrateButton.text, "Migrate")
        compare(dlg.startFreshButton.text, "Start fresh")
    }

    function test_torrentCount() {
        dlg.torrentCount = 3
        verify(text("count").text.indexOf("3") >= 0, "the count is shown: " + text("count").text)
    }

    function test_runningBlocksMigrate() {
        dlg.qbtRunning = true
        verify(!dlg.migrateButton.enabled, "Migrate is blocked")
        verify(dlg.startFreshButton.enabled, "Start fresh still works")
        verify(text("runningNote").visible)
        compare(text("runningNote").text, "Close qBittorrent to migrate your torrents")

        dlg.qbtRunning = false
        verify(dlg.migrateButton.enabled, "Migrate comes back once qBittorrent is closed")
        verify(!text("runningNote").visible)
    }

    function test_clicksEmitSignals() {
        const migrate = signalSpy(dlg, "migrateRequested")
        const fresh = signalSpy(dlg, "startFreshRequested")
        dlg.migrateButton.click()
        compare(migrate.count, 1)
        compare(fresh.count, 0)
        dlg.startFreshButton.click()
        compare(fresh.count, 1)
    }

    function test_blockedMigrateDoesNotEmit() {
        dlg.qbtRunning = true
        const migrate = signalSpy(dlg, "migrateRequested")
        dlg.migrateButton.click()
        compare(migrate.count, 0)
    }

    function test_busy() {
        dlg.busy = true
        verify(!dlg.migrateButton.enabled)
        verify(!dlg.startFreshButton.enabled)
        compare(dlg.migrateButton.text, "Migrating…")
    }

    function test_errors() {
        dlg.errorCode = "target-not-empty"
        verify(text("errorText").visible)
        verify(text("errorText").text.indexOf("nothing was moved") >= 0, text("errorText").text)
        verify(!text("errorDetail").visible)

        dlg.errorCode = "failed"
        dlg.errorDetail = "Cannot copy D:/a.fastresume"
        verify(text("errorText").text.indexOf("did not finish") >= 0, text("errorText").text)
        verify(text("errorDetail").visible)
        compare(text("errorDetail").text, "Cannot copy D:/a.fastresume")

        dlg.errorCode = ""
        verify(!text("errorText").visible)
    }

    function test_russian() {
        verify(FluxTestI18n.setLanguage("ru"), "the Russian translation is built into the app")
        dlg.torrentCount = 12
        dlg.qbtRunning = true
        compare(text("title").text, "Перенести раздачи из qBittorrent?")
        compare(text("runningNote").text, "Закройте qBittorrent, чтобы перенести раздачи")
        compare(text("count").text, "Раздач в профиле qBittorrent: 12")
        compare(dlg.migrateButton.text, "Перенести")
        compare(dlg.startFreshButton.text, "Начать с чистого листа")
    }
}
