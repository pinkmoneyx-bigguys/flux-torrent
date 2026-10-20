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

    function test_searchFillsFreeSpace() {
        // glass look: the search pill takes all the free width
        Theme.style = "glass"
        const s = findChild(main.contentItem, "titleSearch")
        verify(s, "titleSearch exists")
        wait(50)
        const before = s.width
        verify(before >= 220, "search pill is at least 220 px wide")
        main.width += 200
        wait(50)
        tryCompare(s, "width", before + 200)
        main.width -= 200
        Theme.style = "default"
    }

    function test_searchIsCappedInDefaultLook() {
        // default look: a command field of at most 520 px over the left edge of the content inset
        const s = findChild(main.contentItem, "titleSearch")
        main.width = 1440
        wait(50)
        compare(s.width, 520)
        main.width = 1640
        wait(50)
        compare(s.width, 520, "the field does not stretch across a wide window")
        compare(s.mapToItem(main.contentItem, 0, 0).x, findChild(main.contentItem, "pageArea").mapToItem(main.contentItem, 0, 0).x,
                "aligned with the left edge of the content inset")
        main.width = 1440
    }

    function test_searchKeepsMinimumWidthAtMinWindowWidth() {
        main.width = 1100
        tryCompare(main, "width", 1100)
        wait(50)
        const s = findChild(main.contentItem, "titleSearch")
        verify(s.width >= 220, "search pill keeps its 220 px minimum: " + s.width)
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
        verify(checked >= 5, "found the search field, the alt-speed button and three window buttons: " + checked)
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

    function test_speedsShowSessionRates() {
        bar.downloadRate = 52.4 * 1024 * 1024
        bar.uploadRate = 6.1 * 1024 * 1024
        compare(findChild(bar, "titleDownRate").text, "↓ " + Format.speed(52.4 * 1024 * 1024))
        compare(findChild(bar, "titleUpRate").text, "↑ " + Format.speed(6.1 * 1024 * 1024))
        bar.downloadRate = Qt.binding(() => SessionFacade.downloadRate)
        bar.uploadRate = Qt.binding(() => SessionFacade.uploadRate)
        compare(findChild(bar, "titleDownRate").text, "↓ " + Format.speed(SessionFacade.downloadRate))
    }

    function test_speedChangeDoesNotShiftSearch() {
        const s = findChild(main.contentItem, "titleSearch")
        bar.downloadRate = 0
        wait(50)
        const before = s.width
        bar.downloadRate = 512.3 * 1024 * 1024
        wait(50)
        compare(s.width, before, "search pill width does not jump with the speed text")
        bar.downloadRate = Qt.binding(() => SessionFacade.downloadRate)
    }

    function test_altSpeedButton() {
        const b = bar.altSpeedButton
        verify(b.Accessible.name !== "", "alt-speed button has an accessible name")
        compare(b.Accessible.checked, SessionFacade.altSpeedEnabled)
        bar.altSpeedEnabled = true
        compare(b.Accessible.checked, true)
        compare(b.iconColor, Theme.warn, "turtle is amber while alternative limits are on")
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
        mouseClick(findChild(main.contentItem, "titleSearch"))
        tryCompare(palette, "opened", true, 1000, "a click on the search pill opens it too")
        palette.close()
        tryCompare(palette, "visible", false)
    }

    function test_searchPlaceholderAndName() {
        verify(bar.searchField.placeholderText !== "")
        verify(bar.searchField.Accessible.name !== "")
    }
}
