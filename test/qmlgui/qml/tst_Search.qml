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
        findChild(page, "searchSeededOnly").checked = false
        findChild(page, "searchPostersOnly").checked = false
        page.setView("list")
        page.setGridColumns(0)
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

    // No text filter field: "With seeds" and "With posters" narrow the results
    function test_seededAndPostersOnly() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "ubuntu", results: results })
        const list = findChild(page, "searchList")
        verify(!findChild(page, "searchResultFilter"), "no filter field")
        findChild(page, "searchSeededOnly").checked = true
        tryCompare(list, "count", 2)
        findChild(page, "searchSeededOnly").checked = false
        tryCompare(list, "count", 3)

        // with posters: only films a poster was found for; one arriving brings its releases in
        findChild(page, "searchPostersOnly").checked = true
        tryCompare(list.model, "count", 0)
        verify(visibleState("searchNothing"), "says the switches hide everything")
        Posters.setPoster(Posters.film("ubuntu server").key, "https://example.invalid/p.jpg")
        tryCompare(list, "count", 1)
    }

    // Cards in a row: automatic by the width, or as chosen
    function test_gridColumns() {
        SearchEngine.loadDemo({ plugins: plugins, pattern: "ubuntu", results: results })
        page.setView("cards")
        const grid = findChild(page, "searchGrid")
        tryVerify(() => grid.visible)
        verify(findChild(page, "searchColumns").visible, "the choice shows with the cards")
        page.setGridColumns(5)
        compare(grid.columns, 5)
        compare(grid.cellWidth, Math.floor(grid.width / 5))
        page.setGridColumns(0)
        verify(grid.columns >= 2)
        page.setView("list")
        verify(!findChild(page, "searchColumns").visible, "and hides with the list")
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

    // Cards: one per film, its releases grouped under it; a card opens them
    function test_cardsGroupByFilm() {
        SearchEngine.loadDemo({ python: true, plugins: plugins, pattern: "interstellar", results: [
            { name: "Интерстеллар / Interstellar (Кристофер Нолан) [2014, BDRip 1080p]", size: 3000, seeds: 385, leechers: 19, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:a" },
            { name: "Интерстеллар / Interstellar (2014) UHD BDRip 2160p", size: 40000, seeds: 120, leechers: 5, engine: "lime", fileUrl: "magnet:?xt=urn:btih:b" },
            { name: "Interstellar.2014.720p.BluRay.x264", size: 1500, seeds: 30, leechers: 1, engine: "lime", fileUrl: "magnet:?xt=urn:btih:c" },
            { name: "Interstellar (1971) TVRip", size: 700, seeds: 2, leechers: 0, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:d" },
            { name: "Интерстеллар / Interstellar BDRip 720p", size: 1400, seeds: 7, leechers: 0, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:e" }
        ] })
        page.setView("cards")
        const grid = findChild(page, "searchGrid")
        tryVerify(() => grid.visible && grid.count === 2, 2000, "two films: " + grid.count)
        const film = grid.model[0]
        compare(film.title, "Интерстеллар")
        compare(film.year, 2014)
        compare(film.count, 4, "the 2014 film's three releases and the one that names no year")
        compare(film.seeds, 385)
        compare(film.qualities, ["2160p", "1080p", "720p"])

        const dialog = findChild(page, "releasesDialog")
        dialog.show(film)
        tryCompare(dialog, "opened", true)
        compare(findChild(dialog.contentItem, "releaseList").count, 4)
        dialog.close()
        tryCompare(dialog, "visible", false)
        page.setView("list")
        verify(findChild(page, "searchList").visible)
    }

    // What has the words only in its genres is left out until asked for
    function test_exactMatchesOnly() {
        SearchEngine.loadDemo({ python: true, plugins: plugins, pattern: "киберпанк", results: [
            { name: "Киберпанк: Бегущие по краю / Cyberpunk: Edgerunners [2022, WEB-DL 1080p]", size: 3000, seeds: 50, leechers: 1, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:a" },
            { name: "Эксперименты Лэйн / Serial Experiments Lain [1998, аниме, киберпанк, BDRip 1080p]", size: 9000, seeds: 9, leechers: 0, engine: "lime", fileUrl: "magnet:?xt=urn:btih:b" }
        ] })
        page.setView("list")
        const list = findChild(page, "searchList")
        tryCompare(list, "count", 1)
        const loose = findChild(page, "searchLoose")
        tryVerify(() => loose.visible, 2000, "offers the loose match")
        loose.clicked()
        tryCompare(list, "count", 2)
        loose.clicked()
        tryCompare(list, "count", 1)
    }

    // A release named only in Russian joins the film that gives the original title too, and shares its poster
    function test_russianOnlyReleaseJoinsItsFilm() {
        SearchEngine.loadDemo({ python: true, plugins: plugins, pattern: "ella", results: [
            { name: "Космическая Элла / Interstellar Ella [2022, WEB-DL 1080p]", size: 3000, seeds: 5, leechers: 1, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:a" },
            { name: "Космическая Элла WEB-DL 720p", size: 1500, seeds: 3, leechers: 0, engine: "lime", fileUrl: "magnet:?xt=urn:btih:b" },
            { name: "Межзвёздные войны / Interstellar Wars (2016) DVDRip", size: 700, seeds: 2, leechers: 0, engine: "eztv", fileUrl: "magnet:?xt=urn:btih:c" }
        ] })
        page.setView("cards")
        const grid = findChild(page, "searchGrid")
        tryVerify(() => grid.visible && grid.count === 2, 2000, "two films: " + grid.count)
        const ella = grid.model.find(f => f.original === "Interstellar Ella")
        compare(ella.count, 2)

        // with posters: the poster of the film shows its Russian-only release too
        findChild(page, "searchPostersOnly").checked = true
        Posters.setPoster(Posters.film("Космическая Элла / Interstellar Ella [2022]").key, "https://example.invalid/ella.jpg")
        page.setView("list")
        tryCompare(findChild(page, "searchList"), "count", 2)
    }
}
