import QtQuick
import QtTest
import Flux

// The media library over MediaLibraryModel.loadDemo (no session in tests): release-name parsing,
// kinds and counts, search, sorting, grid/list views and the details sheet.
TestCase {
    id: tc
    name: "Media"
    when: windowShown
    width: 1200
    height: 800
    visible: true

    readonly property var items: [
        { torrentId: "a", fileIndex: 0, fileName: "Sintel.2010.1080p.BluRay.x264.mkv", size: 1400, progress: 1, addedSecsAgo: 300 },
        { torrentId: "b", fileIndex: 0, fileName: "Severance.S03E04.1080p.WEB.H264-GRP.mkv", size: 2100, progress: 1, addedSecsAgo: 100 },
        { torrentId: "b", fileIndex: 1, fileName: "Severance.S03E03.1080p.WEB.H264-GRP.mkv", size: 2000, progress: 0.4, addedSecsAgo: 200 },
        { torrentId: "c", fileIndex: 0, fileName: "Big.Buck.Bunny.2008.2160p.60fps.mkv", size: 9000, progress: 0.2, addedSecsAgo: 50 }
    ]

    MediaPage {
        id: page
        anchors.fill: parent
    }

    function init() {
        MediaLibraryModel.kind = "all"
        MediaLibraryModel.search = ""
        MediaLibraryModel.sortKey = "added"
        MediaLibraryModel.loadDemo(items)
        page.view = "grid"
        waitForRendering(page)
    }

    function cleanup() {
        const sheet = findChild(page, "mediaSheet")
        if (sheet.visible) {
            sheet.close()
            tryCompare(sheet, "visible", false)
        }
    }

    function test_parseName_data() {
        return [
            { tag: "movie", name: "Sintel.2010.1080p.BluRay.x264.mkv", title: "Sintel", year: 2010, season: 0, episode: 0, quality: "1080p" },
            { tag: "episode", name: "Severance.S03E04.1080p.WEB.H264-GRP.mkv", title: "Severance", year: 0, season: 3, episode: 4, quality: "1080p" },
            { tag: "4K", name: "Big.Buck.Bunny.2008.4K.mkv", title: "Big Buck Bunny", year: 2008, season: 0, episode: 0, quality: "2160p" },
            { tag: "group tag", name: "[Group] Spring (2019) - Blender Open Movie [1080p].mkv", title: "Spring", year: 2019, season: 0, episode: 0, quality: "1080p" },
            { tag: "NxNN", name: "Show 2x05 720p.mkv", title: "Show", year: 0, season: 2, episode: 5, quality: "720p" },
            { tag: "year title", name: "2001.A.Space.Odyssey.1968.1080p.mkv", title: "2001 A Space Odyssey", year: 1968, season: 0, episode: 0, quality: "1080p" },
            { tag: "plain", name: "home video.mp4", title: "home video", year: 0, season: 0, episode: 0, quality: "" }
        ]
    }

    function test_parseName(data) {
        const p = MediaLibraryModel.parseName(data.name)
        compare(p.title, data.title)
        compare(p.year ?? 0, data.year)
        compare(p.season ?? 0, data.season)
        compare(p.episode ?? 0, data.episode)
        compare(p.quality, data.quality)
    }

    function test_countsAndKinds() {
        const c = MediaLibraryModel.counts
        compare(c.all, 4)
        compare(c.movies, 2)
        compare(c.series, 2)
        compare(c.downloading, 2)
        MediaLibraryModel.kind = "series"
        compare(MediaLibraryModel.count, 2)
        MediaLibraryModel.kind = "downloading"
        compare(MediaLibraryModel.count, 2)
    }

    // One poster a film or series: a show's episodes go together, in order
    function test_newestFirstAndSort() {
        const grid = findChild(page, "mediaGrid")
        compare(grid.count, 3, "the two episodes of the show make one title")
        compare(MediaLibraryModel.titles[0].title, "Big Buck Bunny", "recently added first")
        MediaLibraryModel.sortKey = "title"
        const show = MediaLibraryModel.titles[1]
        compare(show.title, "Severance")
        verify(show.series)
        compare(show.count, 2)
        compare(show.seasons, [3])
        compare(show.items.map(i => i.episode), [3, 4], "episodes of a show in order")
        verify(show.downloading, "one episode is still coming")
        MediaLibraryModel.sortKey = "size"
        compare(MediaLibraryModel.titles[0].title, "Big Buck Bunny")
    }

    // A film plays from its poster; a series opens its episodes
    function test_seriesOpensItsEpisodes() {
        MediaLibraryModel.sortKey = "title"
        const sheet = findChild(page, "mediaSheet")
        page.activate(MediaLibraryModel.titles[1])
        tryCompare(sheet, "opened", true)
        compare(findChild(sheet.contentItem, "mediaSheetTitle").text, "Severance")
        verify(findChild(sheet.contentItem, "mediaEpisodes").visible)
        verify(!findChild(sheet.contentItem, "mediaPlay").visible, "the episodes have their own play")
        sheet.close()
        tryCompare(sheet, "visible", false)

        let played = ""
        const remember = (key, at) => played = key
        page.playRequested.connect(remember)
        page.activate(MediaLibraryModel.titles[2])
        compare(played, "a:0", "Sintel plays")
        page.playRequested.disconnect(remember)
    }

    function test_search() {
        MediaLibraryModel.search = "severance"
        compare(MediaLibraryModel.count, 2)
        MediaLibraryModel.search = "nothing like it"
        compare(MediaLibraryModel.count, 0)
        verify(findChild(page, "mediaEmpty").visible)
    }

    function test_listView() {
        page.view = "list"
        waitForRendering(page)
        verify(findChild(page, "mediaList").visible)
        verify(!findChild(page, "mediaGrid").visible)
        compare(findChild(page, "mediaList").count, 4)
    }

    function test_sheetForIncompleteFile() {
        page.open("c:0")
        const sheet = findChild(page, "mediaSheet")
        tryCompare(sheet, "opened", true)
        compare(findChild(sheet.contentItem, "mediaSheetTitle").text, "Big Buck Bunny")
        verify(findChild(sheet.contentItem, "mediaPlay").enabled, "with the built-in player it plays while downloading")
        page.playerAvailable = false
        verify(!findChild(sheet.contentItem, "mediaPlay").enabled, "without it an incomplete file cannot play yet")
        page.playerAvailable = true
        verify(!MediaLibraryModel.play("c:0"))
        verify(MediaLibraryModel.play("a:0"), "a finished file opens in the system player")
    }

    function test_emptyLibrary() {
        MediaLibraryModel.loadDemo([])
        waitForRendering(page)
        verify(findChild(page, "mediaEmpty").visible)
        compare(MediaLibraryModel.counts.all, 0)
    }
}
