import QtQuick
import QtTest
import Flux

// PlayerView driving a FakePlayer: keys, closing, auto-hiding controls, "Continue from", tracks and
// the saved position.
TestCase {
    id: tc
    name: "Player"
    when: windowShown
    width: 1200
    height: 760
    visible: true

    FakePlayer { id: fake }

    PlayerView {
        id: view
        anchors.fill: parent
        embedded: false
        player: fake
    }

    property bool closedWatched: false
    property int closedCount: 0
    Connections {
        target: view
        function onClosed(watched) { tc.closedWatched = watched; tc.closedCount++ }
    }

    function init() {
        closedCount = 0
        fake.paused = false
        fake.volume = 100
        fake.muted = false
        WatchHistory.clear("t:0")
        view.play("t", 0, "Big Buck Bunny", "1080p", "file:///C:/movie.mkv", false, 0)
        waitForRendering(view)
    }

    function cleanup() {
        if (view.visible)
            view.close()
    }

    function test_opensFile() {
        verify(view.visible)
        compare(fake.source, "file:///C:/movie.mkv")
        verify(view.activeFocus, "keys go to the player")
        compare(findChild(view, "playerBufferBadge").visible, false, "a local file has no stream buffer")
    }

    function test_keys() {
        keyClick(Qt.Key_Space)
        verify(fake.paused)
        keyClick(Qt.Key_Space)
        verify(!fake.paused)
        fake.position = 100
        keyClick(Qt.Key_Right)
        compare(fake.position, 105)
        keyClick(Qt.Key_Left)
        keyClick(Qt.Key_Left)
        compare(fake.position, 95)
        keyClick(Qt.Key_Down)
        compare(fake.volume, 95)
        keyClick(Qt.Key_M)
        verify(fake.muted)
    }

    function test_escapeLeavesFullscreenThenPlayer() {
        keyClick(Qt.Key_F)
        verify(view.fullscreen)
        keyClick(Qt.Key_Escape)
        verify(!view.fullscreen)
        verify(view.visible)
        keyClick(Qt.Key_Escape)
        verify(!view.visible)
        compare(closedCount, 1)
        compare(fake.source, "", "closing stops the file")
    }

    function test_controlsHideWhilePlaying() {
        verify(view.controlsShown)
        tryCompare(view, "controlsShown", false, 4000, "hidden after 2.5 s of playback")
        mouseMove(view, 300, 300)
        verify(view.controlsShown, "the mouse brings them back")
        fake.paused = true
        wait(3000)
        verify(view.controlsShown, "a paused player keeps them")
    }

    function test_resumeChipAndFromStart() {
        view.close()
        view.play("t", 0, "Movie", "", "file:///C:/movie.mkv", false, 754)
        compare(fake.position, 754)
        const chip = findChild(view, "playerResumeChip")
        verify(chip.visible)
        mouseClick(findChild(view, "playerFromStart"))
        compare(fake.position, 0)
    }

    function test_savesPositionOnClose() {
        fake.position = 321
        view.close()
        compare(WatchHistory.position("t:0"), 321)
        verify(!closedWatched)
    }

    function test_watchedToEnd() {
        fake.position = 590
        view.close()
        verify(closedWatched, "95 % counts as watched")
    }

    function test_trackButtons() {
        verify(!findChild(view, "playerAudio").visible, "one audio track: no menu")
        fake.audioTracks = [{ id: 1, title: "", lang: "rus" }, { id: 2, title: "Commentary", lang: "eng" }]
        fake.subtitleTracks = [{ id: 3, title: "", lang: "rus" }]
        verify(findChild(view, "playerAudio").visible)
        verify(findChild(view, "playerSubtitles").visible)
    }

    function test_timeText() {
        fake.position = 3725
        fake.duration = 7200
        compare(findChild(view, "playerTime").text, "1:02:05 / 2:00:00")
    }

    function test_streamBadge() {
        view.close()
        view.play("t", 0, "Movie", "", "http://127.0.0.1:1/x", true, 0)
        verify(findChild(view, "playerBufferBadge").visible)
        verify(findChild(view, "playerStreamMode").visible)
    }
}
