import QtQuick
import QtTest
import Flux

// The application shell: page switching from the sidebar and the keyboard, the window layout, and the
// sidebar labels (English source strings and the Russian translation) at the minimum window width.
TestCase {
    id: tc
    name: "Navigation"
    when: windowShown
    width: 200
    height: 100
    visible: true

    readonly property var navNames: ["nav_transfers", "nav_search", "nav_rss", "nav_media", "nav_settings"]
    readonly property var pageNames: ["page_transfers", "page_search", "page_rss", "page_media", "page_settings"]

    property var main: null

    Component {
        id: mainComponent
        Main {}
    }

    function initTestCase() {
        main = mainComponent.createObject(tc)
        verify(main, "Main.qml loads")
        tryVerify(() => main.visible, 3000, "Main shows itself once the window agent is set up")
    }

    function cleanupTestCase() {
        if (main)
            main.destroy()
        main = null
    }

    function init() {
        FluxTestI18n.setLanguage("")
        main.width = 1440
        main.height = 920
        main.currentPage = 0
        main.requestActivate()
        tryVerify(() => main.active, 3000, "the Flux window is active, so key events reach it")
        waitForRendering(main.contentItem)
    }

    function cleanup() {
        FluxTestI18n.setLanguage("")
        UiSettings.style = "default"
        Theme.style = Qt.binding(() => UiSettings.style)
    }

    function test_styleCardsSwitchTheLook() {
        main.currentPage = 4
        waitForRendering(main.contentItem)
        const glassCard = findChild(main.contentItem, "styleGlass")
        const defaultCard = findChild(main.contentItem, "styleDefault")
        verify(defaultCard.Accessible.checked, "the default look is chosen out of the box")
        mouseClick(glassCard)
        compare(UiSettings.style, "glass")
        verify(Theme.glass, "the window switches to Liquid Glass right away")
        verify(glassCard.Accessible.checked)
        mouseClick(defaultCard)
        compare(UiSettings.style, "default")
        verify(!Theme.glass)
    }

    function nav(i) {
        return findChild(main.contentItem, navNames[i])
    }

    function page(i) {
        return findChild(main.contentItem, pageNames[i])
    }

    function verifyOnPage(index) {
        compare(main.currentPage, index, "currentPage")
        for (let i = 0; i < pageNames.length; ++i) {
            verify(page(i), pageNames[i] + " exists")
            compare(page(i).visible, i === index, pageNames[i] + " visibility")
            compare(nav(i).current, i === index, navNames[i] + " is highlighted only when its page is shown")
        }
    }

    function test_startsOnTransfers() {
        verifyOnPage(0)
    }

    function test_ctrlNumberSwitchesPage_data() {
        return [
            { tag: "Ctrl+1", key: Qt.Key_1, page: 0 },
            { tag: "Ctrl+2", key: Qt.Key_2, page: 1 },
            { tag: "Ctrl+3", key: Qt.Key_3, page: 2 },
            { tag: "Ctrl+4", key: Qt.Key_4, page: 3 },
        ]
    }

    function test_ctrlNumberSwitchesPage(data) {
        main.currentPage = data.page === 0 ? 4 : 0
        keyClick(data.key, Qt.ControlModifier)
        // no transition: the page and the highlight are final right after the key press
        verifyOnPage(data.page)
    }

    function test_settingsShortcut() {
        keyClick(Qt.Key_Comma, Qt.ControlModifier)
        verifyOnPage(4)
    }

    function test_sidebarClick() {
        mouseClick(nav(3))
        verifyOnPage(3)
    }

    function test_sidebarClickSettings() {
        mouseClick(nav(4))
        verifyOnPage(4)
        mouseClick(nav(0))
        verifyOnPage(0)
    }

    function test_sidebarKeyboardActivation() {
        nav(2).forceActiveFocus()
        keyClick(Qt.Key_Space)
        verifyOnPage(2)
    }

    function test_navItemsAreAccessible() {
        for (let i = 0; i < navNames.length; ++i) {
            const item = nav(i)
            verify(item.Accessible.name !== "", navNames[i] + " has an accessible name")
            compare(item.Accessible.role, Accessible.PageTab, navNames[i] + " role")
        }
    }

    function test_settingsSitsAtTheBottom() {
        const sidebar = findChild(main.contentItem, "sidebar")
        const media = nav(3).mapToItem(sidebar, 0, 0)
        const settings = nav(4).mapToItem(sidebar, 0, 0)
        verify(settings.y > media.y + nav(3).height + 100, "a gap separates Settings from the sections")
        compare(settings.y + nav(4).height, sidebar.height - sidebar.padding, "Settings is the last row")
    }

    function test_windowLayoutDefault() {
        const root = main.contentItem
        const sidebar = findChild(root, "sidebar")
        const titleBar = findChild(root, "titleBar")
        const pageArea = findChild(root, "pageArea")
        const pages = findChild(root, "pages")
        const sb = sidebar.mapToItem(root, 0, 0)
        const tb = titleBar.mapToItem(root, 0, 0)
        const pa = pageArea.mapToItem(root, 0, 0)

        compare(tb.x, 0, "the title strip spans the window")
        compare(tb.y, 0)
        compare(titleBar.width, root.width)
        compare(titleBar.height, 44, "title bar height")

        compare(sidebar.width, 236, "sidebar width")
        compare(sb.x, 0, "the sidebar sits flat on the chrome")
        compare(sb.y, titleBar.height)
        compare(sb.y + sidebar.height, root.height - 8)

        compare(pa.x, sb.x + sidebar.width, "the inset starts where the sidebar ends")
        compare(pa.y, sb.y)
        compare(pa.x + pageArea.width, root.width - 8, "8 px inset margin on the right")
        compare(pa.y + pageArea.height, root.height - 8, "8 px inset margin at the bottom: no status bar")
        compare(pageArea.radius, 12)
        compare(pages.width, pageArea.width, "the pages fill the inset")
        verify(!findChild(root, "statusPill"), "the status bar is gone")
    }

    function test_windowLayoutGlass() {
        Theme.style = "glass"
        waitForRendering(main.contentItem)
        const root = main.contentItem
        const sidebar = findChild(root, "sidebar")
        const titleBar = findChild(root, "titleBar")
        const pages = findChild(root, "pages")
        const sb = sidebar.mapToItem(root, 0, 0)
        const tb = titleBar.mapToItem(root, 0, 0)
        const pg = pages.mapToItem(root, 0, 0)

        compare(tb.x, 12, "title bar left margin")
        compare(tb.y, 12, "title bar top margin")
        compare(titleBar.height, 44, "title bar height")
        compare(tb.x + titleBar.width, root.width - 12, "title bar right margin")

        compare(sidebar.width, 236, "sidebar width")
        compare(sidebar.radius, 24, "sidebar radius")
        compare(sb.x, 12, "sidebar left margin")
        compare(sb.y, tb.y + titleBar.height + 12, "12 px between the title bar and the sidebar")

        compare(pg.x, sb.x + sidebar.width + 12, "12 px between the sidebar and the page")
        compare(pg.x + pages.width, root.width - 12, "page right margin")
        compare(pg.y, sb.y, "page and sidebar share the top edge")

        compare(sb.y + sidebar.height, root.height - 12, "sidebar bottom margin: no status bar")
        verify(!findChild(root, "statusPill"), "the status bar is gone")
    }

    function test_labelsFitAtMinWidth() {
        main.width = 1100
        tryCompare(main, "width", 1100)
        wait(50)
        for (const n of navNames) {
            const t = findChild(main.contentItem, n + "_label")
            verify(t, n + "_label exists")
            verify(t.text !== "", n + " has a label")
            verify(!t.truncated, n + " label is not elided: " + t.text)
        }
    }

    function test_russianLabelsFitAtMinWidth() {
        verify(FluxTestI18n.setLanguage("ru"), "the Russian translation is built into the app")
        main.width = 1100
        tryCompare(main, "width", 1100)
        wait(50)
        const expected = ["Передачи", "Поиск по трекерам", "RSS-ленты", "Медиатека", "Настройки"]
        for (let i = 0; i < navNames.length; ++i) {
            const t = findChild(main.contentItem, navNames[i] + "_label")
            compare(t.text, expected[i], navNames[i] + " is translated")
            verify(!t.truncated, navNames[i] + " label is not elided: " + t.text)
        }
        compare(findChild(main.contentItem, "page_rss").title, "RSS-ленты", "page titles are translated too")
    }

    function test_pageTitlesAndHints() {
        for (let i = 0; i < pageNames.length; ++i) {
            const p = page(i)
            verify(p.title !== "", pageNames[i] + " has a title")
            verify(p.hint !== "", pageNames[i] + " has a hint")
        }
    }
}
