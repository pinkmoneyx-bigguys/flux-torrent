import QtQuick
import QtTest
import Flux

// The RSS page over RssManager.loadDemo (no RSS session in tests): feed tree and selection, article
// filters, the reader, the "updates are off" alert and the auto-download rules.
TestCase {
    id: tc
    name: "Rss"
    when: windowShown
    width: 1300
    height: 820
    visible: true

    readonly property string sep: "\\"
    readonly property var demoState: ({
        processing: true,
        feeds: [
            { path: "Shows", name: "Shows", folder: true, depth: 0, unread: 2 },
            { path: "Shows" + sep + "A", name: "A", folder: false, depth: 1, url: "https://a.example/rss", unread: 2 },
            { path: "Linux", name: "Linux", folder: false, depth: 0, url: "https://l.example/rss", unread: 1 }
        ],
        articles: {
            "Shows\\A": [
                { title: "Show S01E02 1080p", secsAgo: 100, torrentUrl: "https://x/1.torrent", description: "<p>Episode <b>two</b></p>" },
                { title: "Show S01E02 720p", secsAgo: 200, torrentUrl: "https://x/2.torrent" },
                { title: "Show S01E01 1080p", secsAgo: 90000, read: true, torrentUrl: "https://x/3.torrent" }
            ],
            "Linux": [ { title: "Fedora 43 Live", secsAgo: 50, link: "https://l.example/fedora" } ]
        },
        rules: [ { name: "Show 1080p", enabled: true, mustContain: "Show 1080p", feeds: ["https://a.example/rss"] } ]
    })

    RssPage {
        id: page
        anchors.fill: parent
    }

    function init() {
        RssManager.loadDemo(demoState)
        RssManager.search = ""
        RssManager.unreadOnly = false
        waitForRendering(page)
    }

    function cleanup() {
        const dialog = findChild(page, "rssRulesDialog")
        if (dialog.visible) {
            dialog.close()
            tryCompare(dialog, "visible", false)
        }
    }

    function articles() {
        return findChild(page, "rssArticleList")
    }

    function test_feedTree() {
        compare(findChild(page, "rssFeedList").count, 4, "All feeds, then the folder and its feeds")
        compare(RssManager.unreadCount, 3)
    }

    function test_selectionFiltersArticles() {
        compare(articles().count, 4, "all feeds: every article, newest first")
        compare(articles().itemAtIndex(0).title, "Fedora 43 Live")
        RssManager.selectedPath = "Linux"
        tryCompare(articles(), "count", 1)
        RssManager.selectedPath = "Shows"
        tryCompare(articles(), "count", 3, 1000, "a folder shows the articles of its feeds")
    }

    function test_unreadAndSearch() {
        RssManager.unreadOnly = true
        tryCompare(articles(), "count", 3)
        RssManager.unreadOnly = false
        RssManager.search = "show 1080p"
        tryCompare(articles(), "count", 2, 1000, "every word must be in the title")
    }

    function test_readerMarksRead() {
        RssManager.selectedPath = "Shows" + sep + "A"
        tryCompare(articles(), "count", 3)
        const card = articles().itemAtIndex(0)
        verify(!card.read)
        mouseClick(card, 40, 20)
        compare(findChild(page, "rssReaderTitle").text, "Show S01E02 1080p")
        tryCompare(card, "read", true, 1000, "opening an article marks it read")
        verify(findChild(page, "rssDownload").visible, "it has a torrent to download")
    }

    function test_noTorrentNoDownloadButton() {
        RssManager.selectedPath = "Linux"
        tryCompare(articles(), "count", 1)
        mouseClick(articles().itemAtIndex(0), 40, 20)
        verify(!findChild(page, "rssDownload").visible)
    }

    function test_updatesOffAlert() {
        const s = Object.assign({}, demoState)
        s.processing = false
        RssManager.loadDemo(s)
        waitForRendering(page)
        verify(findChild(page, "rssOffAlert").visible)
        mouseClick(findChild(page, "rssTurnOn"))
        verify(RssManager.processingEnabled)
        verify(!findChild(page, "rssOffAlert").visible)
    }

    function test_rulePreview() {
        const titles = RssManager.previewRule({ mustContain: "Show 1080p", feeds: ["https://a.example/rss"] })
        compare(titles.length, 2, "both 1080p episodes match, the 720p one does not")
        compare(RssManager.previewRule({ mustContain: "Show 1080p", feeds: [] }).length, 0, "no feeds, no matches")
    }

    function test_rulesDialogCreatesRule() {
        mouseClick(findChild(page, "rssRulesButton"))
        const dialog = findChild(page, "rssRulesDialog")
        tryCompare(dialog, "opened", true)
        compare(dialog.originalName, "Show 1080p", "opens on the first rule")
        mouseClick(findChild(dialog.contentItem, "rssNewRule"))
        compare(dialog.originalName, "")
        dialog.set("name", "Show 1080p")
        dialog.save()
        verify(dialog.error !== "", "names are unique")
        dialog.set("name", "Linux ISOs")
        dialog.save()
        compare(dialog.error, "")
        compare(RssManager.rules.length, 2)
        compare(dialog.originalName, "Linux ISOs", "the new rule stays open for editing")
    }
}
