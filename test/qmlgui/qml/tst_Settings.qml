import QtQuick
import QtTest
import Flux

// The Settings page over AppSettings in memory (no session in tests): section navigation, switches,
// numbers with validation, selects, rows that appear with their switch, and About.
TestCase {
    id: tc
    name: "Settings"
    when: windowShown
    width: 1200
    height: 820
    visible: true

    SettingsPage {
        id: page
        anchors.fill: parent
    }

    function init() {
        page.section = "downloads"
        waitForRendering(page)
    }

    function setting(key) {
        return findChild(page, "setting_" + key)
    }

    function test_sectionsNavigate() {
        verify(!findChild(page, "settingsNav_interface"), "no Interface section: only the default look is offered")
        verify(!findChild(page, "styleDefault"), "no theme cards")
        mouseClick(findChild(page, "settingsNav_speed"))
        compare(page.section, "speed")
        verify(setting("dlLimit").visible)
    }

    // About: the version, the update check and the components
    function test_about() {
        mouseClick(findChild(page, "settingsNav_about"))
        compare(page.section, "about")
        const about = findChild(page, "aboutSection")
        verify(about.visible)
        verify(findChild(about, "aboutVersion").text.indexOf(AppInfo.version) >= 0, "the version is shown")
        verify(AppInfo.version !== "" && AppInfo.baseVersion !== "")
        verify(findChild(about, "updateStatus").text !== "")
        verify(findChild(about, "checkUpdates").visible)
    }

    // Double-click actions are qBittorrent's own settings
    function test_doubleClickSettings() {
        compare(AppSettings.value("dblClickFinished"), "open", "a finished torrent opens its folder by default")
        compare(AppSettings.value("dblClickRunning"), "toggle", "a running one starts or stops")
        verify(setting("dblClickFinished").visible)
    }

    function test_switchApplies() {
        page.section = "bittorrent"
        const before = AppSettings.value("dht")
        mouseClick(setting("dht"))
        compare(AppSettings.value("dht"), !before)
        mouseClick(setting("dht"))
        compare(AppSettings.value("dht"), before)
    }

    function test_numberCommitsOnEnter() {
        page.section = "speed"
        waitForRendering(page)
        const input = setting("dlLimit")
        input.field.forceActiveFocus()
        input.field.selectAll()
        keyClick(Qt.Key_5)
        keyClick(Qt.Key_0)
        keyClick(Qt.Key_Return)
        compare(AppSettings.value("dlLimit"), 50)
    }

    function test_validation() {
        compare(AppSettings.setValue("port", 70000) !== "", true, "ports stop at 65535")
        compare(AppSettings.setValue("port", 51413), "")
        compare(AppSettings.value("port"), 51413)
        verify(AppSettings.setValue("encryption", "sometimes") !== "", "only known options")
        verify(AppSettings.setValue("savePath", "  ") !== "", "a save folder is required")
    }

    function test_dependentRows() {
        page.section = "downloads"
        AppSettings.setValue("downloadPathEnabled", false)
        waitForRendering(page)
        verify(!setting("downloadPath").visible)
        AppSettings.setValue("downloadPathEnabled", true)
        tryVerify(() => setting("downloadPath").visible, 1000, "the incomplete folder shows with its switch")

        page.section = "connection"
        AppSettings.setValue("proxyType", "none")
        waitForRendering(page)
        verify(!setting("proxyHost").visible)
        AppSettings.setValue("proxyType", "socks5")
        tryVerify(() => setting("proxyHost").visible)
        verify(!setting("proxyUser").visible, "credentials only with sign-in on")
        AppSettings.setValue("proxyType", "none")
    }

    // Language: the system's first, then every translation under its own name; a choice is kept
    function test_language() {
        page.section = "language"
        const select = setting("language")
        verify(select.visible)
        const options = Languages.options
        compare(options.length, 10, "system + 9 languages")
        compare(options[0].key, "")
        verify(options[0].label.indexOf("(") > 0, "the system choice names its language: " + options[0].label)
        const labels = options.map(o => o.label)
        for (const name of ["English", "Русский", "Українська", "Deutsch", "Español", "Français", "Português (Brasil)", "Polski", "简体中文"])
            verify(labels.indexOf(name) >= 0, name + " is offered")
        compare(select.currentKey, "")

        Languages.select("de")
        compare(Languages.selected, "de")
        compare(Languages.current, "de")
        tryCompare(select, "currentKey", "de")
        Languages.select("")
        compare(Languages.selected, "")
    }

    // Every language Flux offers has its translation built in
    function test_translationsBuiltIn() {
        for (const o of Languages.options) {
            if (o.key === "" || o.key === "en")
                continue
            verify(FluxTestI18n.setLanguage(o.key), "a translation for " + o.key)
        }
        // English: the plural forms
        verify(FluxTestI18n.setLanguage("en"))
        compare(qsTranslate("SearchPage", "%n result(s) for “%1”", "", 1).arg("x"), "1 result for “x”")
        compare(qsTranslate("SearchPage", "%n result(s) for “%1”", "", 5).arg("x"), "5 results for “x”")
        FluxTestI18n.setLanguage("")
    }

    function test_selectShowsCurrent() {
        page.section = "bittorrent"
        compare(AppSettings.setValue("encryption", "require"), "")
        compare(AppSettings.value("encryption"), "require")
        tryCompare(setting("encryption"), "currentKey", "require")
        AppSettings.setValue("encryption", "prefer")
    }

    function test_scheduleRows() {
        page.section = "speed"
        AppSettings.setValue("schedulerEnabled", false)
        waitForRendering(page)
        verify(!setting("schedulerFrom").visible)
        AppSettings.setValue("schedulerEnabled", true)
        tryVerify(() => setting("schedulerFrom").visible, 1000, "the hours show with the schedule switch")
        verify(setting("schedulerDays").visible)
        verify(AppSettings.setValue("schedulerFrom", "25:00") !== "", "times are checked")
        compare(AppSettings.setValue("schedulerFrom", "07:30"), "")
        compare(AppSettings.setValue("schedulerDays", "weekend"), "")
        verify(AppSettings.setValue("schedulerDays", "someday") !== "")
        AppSettings.setValue("schedulerEnabled", false)
    }

    function test_advancedTable() {
        page.section = "advanced"
        waitForRendering(page)
        const rows = AppSettings.advancedSettings()
        verify(rows.length >= 40, "the advanced table lists the libtorrent knobs: " + rows.length)
        verify(setting("asyncIOThreads").visible)
        verify(setting("diskIOType").visible)
        findChild(page, "advancedSearch").text = "turnover"
        tryVerify(() => { const r = setting("asyncIOThreads"); return !r || !r.visible }, 1000, "search hides other rows")
        verify(setting("peerTurnover").visible)
        findChild(page, "advancedSearch").text = ""
    }

    function test_advancedValidationAndReset() {
        compare(AppSettings.setValue("peerTurnover", 150) !== "", true, "percent stops at 100")
        compare(AppSettings.setValue("hashingThreads", 4), "")
        compare(AppSettings.value("hashingThreads"), 4)
        compare(AppSettings.resetValue("hashingThreads"), "")
        compare(AppSettings.value("hashingThreads"), 1, "back to the default")
        verify(AppSettings.setValue("diskIOType", "floppy") !== "")
    }

    function test_resetAll() {
        page.section = "advanced"
        AppSettings.setValue("connectionSpeed", 99)
        AppSettings.setValue("announceToAllTrackers", true)
        mouseClick(findChild(page, "advancedResetAll"))
        const dialog = findChild(page, "advancedResetDialog")
        tryCompare(dialog, "opened", true)
        mouseClick(findChild(dialog.contentItem, "advancedResetConfirm"))
        tryCompare(dialog, "visible", false)
        compare(AppSettings.value("connectionSpeed"), 30)
        compare(AppSettings.value("announceToAllTrackers"), false)
    }
}
