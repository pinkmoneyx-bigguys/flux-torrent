import QtQuick

// Stands in for MpvItem in PlayerView tests (no OpenGL on the offscreen platform): the same properties,
// methods and signals, driven by the test.
Item {
    property bool available: true
    property string source
    property real startPosition: 0
    property bool paused: false
    property real position: 0
    property real duration: 0
    property real cachedUntil: 0
    property bool buffering: false
    property bool seeking: false
    property bool loaded: false
    property int volume: 100
    property bool muted: false
    property var audioTracks: []
    property var subtitleTracks: []
    property int audioTrack: 0
    property int subtitleTrack: 0
    property real bitrate: 0
    property string hwdec: "auto-safe"
    property string error: ""

    signal fileLoaded()
    signal endReached()

    function togglePause() { paused = !paused }
    function seek(seconds) { position = Math.max(0, seconds) }
    function seekRelative(seconds) { position = Math.max(0, position + seconds) }
    function stop() { source = "" }
    function addSubtitle(path) {}

    // the test "loads" the file
    onSourceChanged: {
        loaded = false
        if (source !== "") {
            position = startPosition
            duration = 600
            loaded = true
            fileLoaded()
        }
    }
}
