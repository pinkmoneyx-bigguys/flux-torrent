import QtQuick
import QtTest
import Flux

// The tracker search page over SearchEngine.loadDemo (no Python, no plugin manager in tests):
// the blocking empty states, results with filter and sorting, and the plugins dialog.
TestCase {
    id: tc
    name: "Search"
    when: windowShown
    width: 1200
    height: 800
    visible: true

    readonly property var plugins: [
        { name: "eztv", fullName: "EZTV", url: "https://eztv.example", version: "1.0", enabled: true },
        { name: "lime", fullName: "LimeTorrents", url: "https://lime.example", version: "4.1", enabled: true },
        { name: "off", fullName: "Turned Off", url: "https://off.example", version: "2.0", enabled: false }
    ]
    readonly property var results: [
        { name: "ubuntu desktop", size: 6000, seeds: 900, leechers: 10, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:1" },
        { name: "ubuntu server", size: 3000, seeds: 40, leechers: 2, engine: "lime", fileUrl: "magnet:?xt=urn:btih:2" },
        { name: "kubuntu", size: 4000, seeds: 0, leechers: 0, engine: "lime", fileUrl: "magnet:?xt=urn:btih:3" }
    ]

    SearchPage {
        id: page
        anchors.fill: parent
    }

    function visibleState(name) {
        const item = findChild(page, name)
        return item && item.visible
    }

    function cleanup() {
        findChild(page, "searchResultFilter").text = ""
        const dialog = findChild(page, "pluginsDialog")
        if (dialog.visible) {
            dialog.close()
            tryCompare(dialog, "visible", false)
        }
    }

    function test_noPython() {
        SearchEngine.loadDemo({ python: false })
        waitForRendering(page)
        verify(visibleState("searchNoPython"), "explains that Python is needed")
        verify(!findChild(page, "searchQuery").enabled, "the query bar is off")
        verify(!findChild(page, "pluginsButton").enabled)
    }

    function test_noPlugins() {
        SearchEngine.loadDemo({ python: true, plugins: [] })
        waitForRendering(page)
        verify(!visibleState("searchNoPython"))
        verify(visibleState("searchNoPlugins"), "offers to install plugins")
    }

    function test_idle() {
        SearchEngine.loadDemo({ plugins: plugins })
        waitForRendering(page)
        verify(visibleState("searchIdle"))
        compare(SearchEngine.enabledPluginCount, 2)
        compare(findChild(page, "pluginsButton").text.indexOf("2") >= 0, true, "the button shows how many plugins are on")
        const select = findChild(page, "searchPlugin")
        compare(select.model.length, 3, "all enabled plugins, then each enabled one")
    }

    function test_resultsSortedBySeeds() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "ubuntu", results: results })
        waitForRendering(page)
        const list = findChild(page, "searchList")
        verify(list.visible)
        compare(list.count, 3)
        compare(list.model.sortKey, "seeds", "most seeded first by default")
        compare(list.itemAtIndex(0).name, "ubuntu desktop")
        verify(findChild(page, "searchStatus").text.indexOf("ubuntu") >= 0, "the status names the query")
    }

    function test_filterAndSeededOnly() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "ubuntu", results: results })
        const list = findChild(page, "searchList")
        findChild(page, "searchResultFilter").text = "server"
        tryCompare(list, "count", 1)
        findChild(page, "searchResultFilter").text = "nothing like it"
        tryCompare(list.model, "count", 0)
        verify(visibleState("searchNothing"), "says the filter hides everything")
        findChild(page, "searchResultFilter").text = ""
        list.model.seededOnly = true
        tryCompare(list, "count", 2)
        list.model.seededOnly = false
    }

    function test_sortCycle() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "ubuntu", results: results })
        const model = findChild(page, "searchList").model
        page.sortBy("size")
        compare(model.descending, true)
        page.sortBy("size")
        compare(model.descending, false)
        page.sortBy("size")
        compare(model.sortKey, "", "third click: arrival order")
    }

    function test_nothingFound() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "zzz", results: [] })
        waitForRendering(page)
        verify(visibleState("searchNothing"))
    }

    function test_failed() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "x", status: "failed", error: "Boom" })
        waitForRendering(page)
        verify(visibleState("searchNothing"))
        compare(findChild(page, "searchStatus").text, "Boom")
    }

    function test_pluginsDialogListsPlugins() {
        SearchEngine.loadDemo({ plugins: plugins })
        mouseClick(findChild(page, "pluginsButton"))
        const dialog = findChild(page, "pluginsDialog")
        tryCompare(dialog, "opened", true)
        compare(findChild(dialog.contentItem, "pluginList").count, 3, "every installed plugin, on or off")
    }
}
