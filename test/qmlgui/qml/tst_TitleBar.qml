import QtQuick
import QtTest
import QWindowKit
import Flux

// The custom title bar of the frameless window: layout, live speeds, the alternative-limits toggle,
// window buttons, and that QWindowKit knows every clickable part of it (the rest drags the window).
TestCase {
    id: tc
    name: "TitleBar"
    when: windowShown
    width: 200
    height: 100
    visible: true

    property var main: null
    property var bar: null

    Component {
        id: mainComponent
        Main {}
    }

    function initTestCase() {
        main = mainComponent.createObject(tc)
        verify(main, "Main.qml loads")
        tryVerify(() => main.visible, 3000)
        bar = findChild(main.contentItem, "titleBar")
        verify(bar, "titleBar exists")
    }

    function cleanupTestCase() {
        if (main)
            main.destroy()
        main = null
    }

    function init() {
        main.showNormal()
        tryCompare(main, "visibility", Window.Windowed)
        main.width = 1440
        main.height = 920
        main.requestActivate()
        tryVerify(() => main.active, 3000)
        waitForRendering(main.contentItem)
    }

    // No search in the bar (Ctrl+K opens the command palette); at the narrowest window the actions
    // and the window buttons still fit after the logo
    function test_noSearchAndActionsFit() {
        verify(!findChild(main.contentItem, "titleSearch"), "no search pill")
        main.width = main.minimumWidth
        tryCompare(main, "width", main.minimumWidth)
        wait(50)
        const logo = findChild(main.contentItem, "titleLogo")
        const actions = findChild(main.contentItem, "titleActions")
        verify(actions.mapToItem(bar, 0, 0).x >= logo.width, "the actions do not run into the logo")
        const right = bar.minimizeButton.parent.mapToItem(bar, bar.minimizeButton.parent.width, 0).x
        verify(right <= bar.width + 0.5, "window buttons stay inside the title bar")
    }

    function test_hitTestAt150pct() {
        // logic only: all interactive title bar elements are registered in the agent
        verify(main.titleBarHitTestItems.length >= 5)
        for (const item of main.titleBarHitTestItems)
            verify(main.windowAgent.isHitTestVisible(item), item + " is registered as hit-test visible")
    }

    // Every control in the title bar must be clickable, so it or an ancestor inside the bar is
    // registered with the agent (or it is one of the system buttons)
    function test_everyInteractiveItemIsRegistered() {
        const agent = main.windowAgent
        const systemButtons = [agent.systemButton(WindowAgent.Minimize), agent.systemButton(WindowAgent.Maximize),
                               agent.systemButton(WindowAgent.Close)]
        let checked = 0
        function covered(item) {
            for (let p = item; p && p !== bar; p = p.parent) {
                if (agent.isHitTestVisible(p) || systemButtons.indexOf(p) >= 0)
                    return true
            }
            return false
        }
        function visit(item) {
            const interactive = (item.checkable !== undefined && item.pressed !== undefined) // AbstractButton
                    || item.cursorPosition !== undefined // text input
            if (interactive && item.visible) {
                ++checked
                verify(covered(item), "interactive title bar item is registered: " + item + " " + item.objectName)
            }
            for (let i = 0; i < item.children.length; ++i)
                visit(item.children[i])
        }
        visit(bar)
        verify(checked >= 5, "found the logo, the actions and three window buttons: " + checked)
    }

    function test_titleBarAndSystemButtons() {
        const agent = main.windowAgent
        compare(agent.titleBar(), main.titleBarArea, "the title bar area is the drag area")
        compare(agent.systemButton(WindowAgent.Minimize), bar.minimizeButton)
        compare(agent.systemButton(WindowAgent.Maximize), bar.maximizeButton)
        compare(agent.systemButton(WindowAgent.Close), bar.closeButton)
        // the drag area reaches the top edge of the window, above the pills
        compare(main.titleBarArea.mapToItem(main.contentItem, 0, 0).y, 0)
        compare(main.titleBarArea.width, main.contentItem.width)
    }

    // The session speeds live at the bottom of the sidebar now
    function test_speedsShowSessionRates() {
        const sidebar = findChild(main.contentItem, "sidebar")
        sidebar.downloadRate = 52.4 * 1024 * 1024
        sidebar.uploadRate = 6.1 * 1024 * 1024
        compare(findChild(sidebar, "sidebarDownRate").text, "↓ " + Format.speed(52.4 * 1024 * 1024))
        compare(findChild(sidebar, "sidebarUpRate").text, "↑ " + Format.speed(6.1 * 1024 * 1024))
        sidebar.downloadRate = Qt.binding(() => SessionFacade.downloadRate)
        sidebar.uploadRate = Qt.binding(() => SessionFacade.uploadRate)
        verify(!findChild(bar, "titleDownRate"), "no speeds in the title bar")
    }

    // A click on the logo folds the sidebar to a rail of icons and back
    function test_logoFoldsSidebar() {
        const sidebar = findChild(main.contentItem, "sidebar")
        const wasCollapsed = main.sidebarCollapsed
        if (wasCollapsed)
            main.toggleSidebar()
        tryCompare(sidebar, "width", sidebar.expandedWidth, 2000)
        mouseClick(bar.logoButton)
        compare(main.sidebarCollapsed, true)
        tryCompare(sidebar, "width", sidebar.railWidth, 2000)
        verify(!findChild(sidebar, "sidebarStatusFilters").visible, "the status filters fold away")
        compare(findChild(main.contentItem, "titleLogo").width, sidebar.width, "the logo block follows the rail")
        mouseClick(bar.logoButton)
        compare(main.sidebarCollapsed, false)
        tryCompare(sidebar, "width", sidebar.expandedWidth, 2000)
    }

    function test_actionButtons() {
        for (const name of ["titleAddTorrent", "titleAddLink", "titleCreateTorrent", "titleStartAll", "titleStopAll", "titleAltSpeed"]) {
            const b = findChild(bar, name)
            verify(b && b.visible, name + " is there")
            verify(b.Accessible.name !== "", name + " has a name")
        }
        mouseClick(findChild(bar, "titleCreateTorrent"))
        const dialog = findChild(main.contentItem, "createTorrentDialog") ?? findChild(main, "createTorrentDialog")
        tryCompare(dialog, "opened", true)
        dialog.close()
        tryCompare(dialog, "visible", false)
    }

    function test_altSpeedButton() {
        const b = bar.altSpeedButton
        verify(b.Accessible.name !== "", "alt-speed button has an accessible name")
        compare(b.Accessible.checked, SessionFacade.altSpeedEnabled)
        bar.altSpeedEnabled = true
        compare(b.Accessible.checked, true)
        compare(b.checked, true, "turtle is lit while alternative limits are on")
        bar.altSpeedEnabled = false
        compare(b.Accessible.checked, false)
        bar.altSpeedEnabled = Qt.binding(() => SessionFacade.altSpeedEnabled)
    }

    function test_windowButtonsHaveNames() {
        for (const b of [bar.minimizeButton, bar.maximizeButton, bar.closeButton])
            verify(b.Accessible.name !== "", b + " has an accessible name")
    }

    function test_maximizeButtonToggles() {
        mouseClick(bar.maximizeButton)
        tryCompare(main, "visibility", Window.Maximized)
        mouseClick(bar.maximizeButton)
        tryCompare(main, "visibility", Window.Windowed)
    }

    function test_minimizeButton() {
        mouseClick(bar.minimizeButton)
        tryCompare(main, "visibility", Window.Minimized)
        main.showNormal()
        tryCompare(main, "visibility", Window.Windowed)
    }

    function test_ctrlKOpensCommandPalette() {
        main.contentItem.forceActiveFocus()
        keyClick(Qt.Key_K, Qt.ControlModifier)
        const palette = findChild(main.contentItem, "commandPalette") ?? findChild(main, "commandPalette")
        verify(palette, "the window has a command palette")
        tryCompare(palette, "opened", true)
        tryVerify(() => findChild(palette.contentItem, "commandInput").activeFocus, 1000, "typing goes into the palette")
        keyClick(Qt.Key_Escape)
        tryCompare(palette, "visible", false)
    }
}
