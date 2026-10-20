import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// The built-in player over the window: video, a top bar (back, title, stream buffer), and the controls at
// the bottom (play, seek bar with what is downloaded ahead, time, stream mode, audio and subtitles, volume,
// full screen). The controls hide after 2.5 s without the mouse while playing.
// Keys: Space play/pause, ←/→ 5 s, ↑/↓ volume, M mute, F full screen, Esc leaves full screen, then the player.
//
// `player` is the MpvItem it drives; tests set `embedded: false` and hand in a fake with the same API.
FocusScope {
    id: view
    objectName: "playerView"

    property bool embedded: true
    property var player: embedded ? mpvLoader.item : null
    // false when Flux was built without libmpv
    readonly property bool available: embedded ? (mpvLoader.item ? mpvLoader.item.available : false) : true

    property string torrentId
    property int fileIndex: -1
    property string title
    property string subtitle
    // playing through the stream server (the file is still downloading)
    property bool streaming: false
    property bool fullscreen: false
    readonly property bool active: visible
    readonly property string historyKey: torrentId !== "" ? WatchHistory.keyOf(torrentId, fileIndex) : ""

    signal closed(bool watchedToEnd)
    signal fullscreenToggled(bool on)

    // Starts a file: `url` is a file URL or the stream URL; `startAt` in seconds
    function play(id, index, name, detail, url, isStream, startAt) {
        torrentId = id
        fileIndex = index
        title = name
        subtitle = detail ?? ""
        streaming = isStream
        resumedFrom = startAt > 0 ? startAt : 0
        visible = true
        forceActiveFocus()
        showControls()
        if (player) {
            player.startPosition = resumedFrom
            player.source = ""
            player.source = url
            player.paused = false
        }
    }

    function close() {
        if (!visible)
            return
        const watched = player && player.duration > 0 && player.position >= player.duration * 0.95
        saveHistory()
        WatchHistory.flush()
        if (player) {
            player.source = ""
        }
        if (fullscreen)
            setFullscreen(false)
        visible = false
        closed(watched || endedHere)
        endedHere = false
    }

    function setFullscreen(on) {
        fullscreen = on
        fullscreenToggled(on)
    }

    function saveHistory() {
        if (player && historyKey !== "" && player.position > 0)
            WatchHistory.save(historyKey, player.position, player.duration)
    }

    property real resumedFrom: 0
    property bool endedHere: false

    // --- Auto-hiding controls -------------------------------------------------------------------
    property bool controlsShown: true
    readonly property bool keepControls: !player || player.paused || !player.loaded || menusOpen || seekBar.dragging
    property bool menusOpen: false
    function showControls() {
        controlsShown = true
        hideTimer.restart()
    }
    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: if (!view.keepControls) view.controlsShown = false
    }
    onKeepControlsChanged: if (keepControls) controlsShown = true; else hideTimer.restart()

    visible: false

    Keys.onPressed: event => {
        if (!player)
            return
        switch (event.key) {
        case Qt.Key_Space:
            player.togglePause()
            break
        case Qt.Key_Left:
            player.seekRelative(-5)
            break
        case Qt.Key_Right:
            player.seekRelative(5)
            break
        case Qt.Key_Up:
            player.volume = Math.min(130, player.volume + 5)
            break
        case Qt.Key_Down:
            player.volume = Math.max(0, player.volume - 5)
            break
        case Qt.Key_M:
            player.muted = !player.muted
            break
        case Qt.Key_F:
            view.setFullscreen(!view.fullscreen)
            break
        case Qt.Key_Escape:
            if (view.fullscreen)
                view.setFullscreen(false)
            else
                view.close()
            break
        default:
            return
        }
        view.showControls()
        event.accepted = true
    }

    // position and stream stats
    Timer {
        interval: 5000
        repeat: true
        running: view.visible && view.player !== null && !view.player.paused
        onTriggered: view.saveHistory()
    }
    property var stats: ({})
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: view.visible && view.streaming
        onTriggered: view.stats = StreamManager.stats(view.torrentId, view.fileIndex)
    }
    // seconds of video on disk ahead of the playhead (stream)
    readonly property real bufferedSeconds: streaming && player && player.bitrate > 0 && stats.bufferedAhead !== undefined
                                            ? stats.bufferedAhead / player.bitrate : 0

    Connections {
        target: view.player
        ignoreUnknownSignals: true
        function onBitrateChanged() {
            if (view.streaming && view.player.bitrate > 0)
                StreamManager.setBitrate(view.torrentId, view.fileIndex, view.player.bitrate)
        }
        function onEndReached() {
            view.endedHere = true
            view.saveHistory()
            view.showControls()
        }
    }

    // --- Video ---------------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    Loader {
        id: mpvLoader
        anchors.fill: parent
        active: view.embedded
        sourceComponent: MpvItem {
            hwdec: AppSettings.value("hardwareDecoding") === false ? "no" : "auto-safe"
        }
    }

    // the whole surface: click pauses, double click full screen, moving the mouse shows the controls
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: view.controlsShown ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: view.showControls()
        onClicked: if (view.player) view.player.togglePause()
        onDoubleClicked: view.setFullscreen(!view.fullscreen)
    }

    // buffering / loading / error in the middle
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.sp(3)
        visible: view.player && (view.player.error !== "" || view.player.buffering || !view.player.loaded)

        UiSpinner {
            Layout.alignment: Qt.AlignHCenter
            visible: view.player && view.player.error === ""
            size: 32
            color: "#FFFFFF"
        }
        Text {
            objectName: "playerStatus"
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 480
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: !view.player ? ""
                : view.player.error !== "" ? qsTr("Can't play this file: %1").arg(view.player.error)
                : !view.player.loaded ? (view.streaming ? qsTr("Fetching the start of the file…") : qsTr("Opening…"))
                : qsTr("Waiting for the download…")
            color: "#FFFFFF"
            font.family: Theme.fontText
            font.pixelSize: Theme.textBase
            style: Text.Raised
            styleColor: Qt.rgba(0, 0, 0, 0.6)
        }
    }

    // --- Top bar ---------------------------------------------------------------------------------
    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 72
        opacity: view.controlsShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: 200 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.7) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: Theme.sp(3)

            PlayerButton {
                objectName: "playerBack"
                iconPath: Icons.chevronDown
                iconRotation: 90
                Accessible.name: qsTr("Back")
                onClicked: view.close()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: view.title
                    color: "#FFFFFF"
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textBase
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    visible: view.subtitle !== ""
                    Layout.fillWidth: true
                    text: view.subtitle
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    elide: Text.ElideRight
                }
            }
            // stream buffer badge
            Rectangle {
                objectName: "playerBufferBadge"
                visible: view.streaming
                implicitWidth: badgeText.implicitWidth + 20
                implicitHeight: 26
                radius: 13
                color: Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: view.stats.complete ? qsTr("Downloaded")
                        : qsTr("Buffer %1 · %2").arg(view.player && view.player.bitrate > 0 ? view.formatTime(view.bufferedSeconds) : "…")
                                                .arg(Format.speed(view.stats.downloadRate ?? 0))
                    color: "#FFFFFF"
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    font.features: { "tnum": 1 }
                }
            }
        }
    }

    // --- "Continue from" chip --------------------------------------------------------------------
    Rectangle {
        objectName: "playerResumeChip"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: topBar.bottom
        visible: view.resumedFrom > 0 && resumeChipTimer.running
        implicitWidth: resumeRow.implicitWidth + 16
        implicitHeight: 36
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.6)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.15)
        Timer {
            id: resumeChipTimer
            interval: 6000
            running: view.visible && view.resumedFrom > 0
        }
        RowLayout {
            id: resumeRow
            anchors.centerIn: parent
            spacing: Theme.sp(2)
            Text {
                Layout.leftMargin: 6
                text: qsTr("Continued from %1").arg(view.formatTime(view.resumedFrom))
                color: "#FFFFFF"
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
            }
            UiButton {
                objectName: "playerFromStart"
                variant: "secondary"
                implicitHeight: 26
                text: qsTr("From the start")
                onClicked: {
                    view.player.seek(0)
                    view.resumedFrom = 0
                }
            }
        }
    }

    // --- Bottom controls -------------------------------------------------------------------------
    Item {
        id: bottomBar
        objectName: "playerControls"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 112
        opacity: view.controlsShown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: 200 }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottomMargin: 14
            spacing: 6

            Item { Layout.fillHeight: true }

            SeekBar {
                id: seekBar
                objectName: "playerSeekBar"
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(2)

                PlayerButton {
                    objectName: "playerPlayPause"
                    iconPath: view.player && !view.player.paused ? Icons.pause : Icons.play
                    Accessible.name: view.player && !view.player.paused ? qsTr("Pause") : qsTr("Play")
                    onClicked: view.player.togglePause()
                }
                PlayerButton {
                    iconPath: Icons.refresh
                    iconMirror: true
                    Accessible.name: qsTr("Back 10 seconds")
                    onClicked: view.player.seekRelative(-10)
                }
                Text {
                    objectName: "playerTime"
                    Layout.leftMargin: 6
                    text: view.player ? view.formatTime(view.player.position) + " / " + view.formatTime(view.player.duration) : ""
                    color: "#FFFFFF"
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textSm
                    font.features: { "tnum": 1 }
                }
                Item { Layout.fillWidth: true }

                UiSelect {
                    objectName: "playerStreamMode"
                    visible: view.streaming
                    implicitHeight: 30
                    Layout.preferredWidth: 150
                    text: qsTr("Stream mode")
                    currentKey: StreamManager.mode
                    model: [
                        { key: "fast", label: qsTr("Fast start") },
                        { key: "smooth", label: qsTr("Smooth") },
                        { key: "economy", label: qsTr("Economy") }
                    ]
                    onActivated: key => StreamManager.mode = key
                }
                PlayerButton {
                    objectName: "playerAudio"
                    visible: view.player && view.player.audioTracks.length > 1
                    iconPath: Icons.audio
                    Accessible.name: qsTr("Audio track")
                    onClicked: {
                        trackMenu.kind = "audio"
                        trackMenu.popup(this, 0, -trackMenu.implicitHeight - 8)
                    }
                }
                PlayerButton {
                    objectName: "playerSubtitles"
                    visible: view.player && view.player.subtitleTracks.length > 0
                    iconPath: Icons.file
                    Accessible.name: qsTr("Subtitles")
                    onClicked: {
                        trackMenu.kind = "sub"
                        trackMenu.popup(this, 0, -trackMenu.implicitHeight - 8)
                    }
                }
                PlayerButton {
                    objectName: "playerMute"
                    iconPath: view.player && (view.player.muted || view.player.volume === 0) ? Icons.x : Icons.audio
                    Accessible.name: qsTr("Mute")
                    onClicked: view.player.muted = !view.player.muted
                }
                Slider {
                    id: volumeSlider
                    objectName: "playerVolume"
                    Layout.preferredWidth: 96
                    from: 0
                    to: 130
                    value: view.player ? view.player.volume : 100
                    onMoved: view.player.volume = Math.round(value)
                    focusPolicy: Qt.NoFocus
                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: volumeSlider.availableWidth
                        height: 4
                        radius: 2
                        color: Qt.rgba(1, 1, 1, 0.25)
                        Rectangle {
                            width: volumeSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: "#FFFFFF"
                        }
                    }
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFFFFF"
                    }
                }
                PlayerButton {
                    objectName: "playerFullscreen"
                    iconPath: Icons.maximize
                    Accessible.name: view.fullscreen ? qsTr("Exit full screen") : qsTr("Full screen")
                    onClicked: view.setFullscreen(!view.fullscreen)
                }
            }
        }
    }

    UiMenu {
        id: trackMenu
        property string kind: "audio"
        onAboutToShow: view.menusOpen = true
        onAboutToHide: view.menusOpen = false

        Instantiator {
            model: !view.player ? [] : trackMenu.kind === "audio" ? view.player.audioTracks
                                     : [{ id: 0, title: qsTr("Off"), lang: "" }].concat(view.player.subtitleTracks)
            onObjectAdded: (index, object) => trackMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => trackMenu.removeItem(object)
            UiMenuItem {
                required property var modelData
                readonly property bool current: trackMenu.kind === "audio" ? view.player.audioTrack === modelData.id
                                                                             : view.player.subtitleTrack === modelData.id
                text: [modelData.title, modelData.lang].filter(s => s && s !== "").join(" · ") || qsTr("Track %1").arg(modelData.id)
                iconPath: current ? Icons.check : ""
                leftPadding: current ? 8 : 32
                onTriggered: {
                    if (trackMenu.kind === "audio")
                        view.player.audioTrack = modelData.id
                    else
                        view.player.subtitleTrack = modelData.id
                }
            }
        }
    }

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00"
        const s = Math.floor(seconds % 60)
        const m = Math.floor(seconds / 60) % 60
        const h = Math.floor(seconds / 3600)
        const pad = n => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    }

    // --- Pieces ---------------------------------------------------------------------------------
    component PlayerButton: AbstractButton {
        id: pb
        property string iconPath
        property real iconRotation: 0
        property bool iconMirror: false
        implicitWidth: 36
        implicitHeight: 36
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        Accessible.role: Accessible.Button
        background: Rectangle {
            radius: 18
            color: pb.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
        }
        contentItem: Item {
            Icon {
                anchors.centerIn: parent
                path: pb.iconPath
                size: 18
                strokeWidth: 2
                color: "#FFFFFF"
                rotation: pb.iconRotation
                transform: Scale { origin.x: 9; xScale: pb.iconMirror ? -1 : 1 }
            }
        }
    }

    // Seek bar: the played part, what mpv already read, what the torrent has on disk ahead, and a handle
    component SeekBar: Item {
        id: sb
        readonly property real duration: view.player ? view.player.duration : 0
        readonly property real position: view.player ? view.player.position : 0
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : position
        function frac(t) { return duration > 0 ? Math.max(0, Math.min(1, t / duration)) : 0 }

        implicitHeight: 20

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: area.containsMouse || sb.dragging ? 6 : 4
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.2)

            // on disk ahead of the playhead (stream)
            Rectangle {
                visible: view.streaming
                x: sb.frac(sb.position) * parent.width
                width: Math.max(0, Math.min(parent.width - x, sb.frac(view.bufferedSeconds) * parent.width))
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.25)
            }
            // read by the player
            Rectangle {
                width: sb.frac(view.player ? view.player.cachedUntil : 0) * parent.width
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(1, 1, 1, 0.35)
            }
            Rectangle {
                width: sb.frac(sb.shown) * parent.width
                height: parent.height
                radius: parent.radius
                color: "#FFFFFF"
            }
            Rectangle {
                visible: area.containsMouse || sb.dragging
                x: sb.frac(sb.shown) * parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: "#FFFFFF"
            }
        }

        // time under the pointer
        Rectangle {
            visible: area.containsMouse && sb.duration > 0
            x: Math.max(0, Math.min(sb.width - width, area.mouseX - width / 2))
            y: -height - 6
            width: hoverTime.implicitWidth + 14
            height: 22
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.75)
            Text {
                id: hoverTime
                anchors.centerIn: parent
                text: view.formatTime(sb.frac(area.mouseX / sb.width * sb.duration) * sb.duration)
                color: "#FFFFFF"
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                font.features: { "tnum": 1 }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                sb.dragging = true
                sb.dragValue = Math.max(0, Math.min(1, mouse.x / width)) * sb.duration
            }
            onPositionChanged: mouse => {
                view.showControls()
                if (sb.dragging)
                    sb.dragValue = Math.max(0, Math.min(1, mouse.x / width)) * sb.duration
            }
            onReleased: {
                if (sb.dragging && view.player)
                    view.player.seek(sb.dragValue)
                sb.dragging = false
            }
        }
    }
}
