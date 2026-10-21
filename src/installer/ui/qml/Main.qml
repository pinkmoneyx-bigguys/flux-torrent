import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes
import QWindowKit
import FluxSetup

import "Strings.js" as S

// The setup's window, in Flux's own look: a brand pane on the left (the logo drawing its wave, the
// version, the steps), the page on the right. Install: welcome, options, progress, done. Update (from
// Flux's updater): progress, then Flux opens again. Uninstall: confirm, progress, done.
Window {
    id: win

    readonly property string mode: Setup.mode
    readonly property string lang: Setup.language
    function t(key, a, b) { return S.t(win.lang, key, a, b) }

    // open Flux when the setup closes (the done page's switch)
    property bool launchAfter: true
    // pages: "welcome", "options", "progress", "done", "confirm"
    property string page: mode === "update" ? "progress" : mode === "uninstall" ? "confirm" : "welcome"
    readonly property var steps: mode === "uninstall" ? [["confirm", "step.confirm"], ["progress", "step.remove"], ["done", "step.done"]]
                               : mode === "update" ? [["progress", "step.update"], ["done", "step.done"]]
                               : [["welcome", "step.welcome"], ["options", "step.options"], ["progress", "step.install"], ["done", "step.done"]]

    width: 820
    height: 520
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: false
    color: c.background
    title: t("window.title")

    // Flux's colours (its default look)
    QtObject {
        id: c
        readonly property color background: "#0A0A0A"
        readonly property color pane: "#111111"
        readonly property color card: "#171717"
        readonly property color muted: "#262626"
        readonly property color border: Qt.rgba(1, 1, 1, 0.10)
        readonly property color input: Qt.rgba(1, 1, 1, 0.15)
        readonly property color text: "#FAFAFA"
        readonly property color dim: "#A1A1A1"
        readonly property color faint: "#737373"
        readonly property color primary: "#E5E5E5"
        readonly property color primaryText: "#171717"
        readonly property color blue: "#60A5FA"
        readonly property color green: "#4ADE80"
        readonly property color violet: "#A78BFA"
        readonly property color warn: "#FBBF24"
        readonly property color error: "#FF6467"
        readonly property string font: "Geist"
        readonly property string mono: "Geist Mono"
    }

    // a size in the setup's language: its units and decimal point
    function size(bytes) {
        const units = t("units").split(" ")
        let v = bytes, i = 0
        while (v >= 1024 && i < units.length - 1) { v /= 1024; ++i }
        const number = i < 2 ? String(Math.round(v)) : v.toFixed(1).replace(".", Qt.locale(win.lang).decimalPoint)
        return number + " " + units[i]
    }

    WindowAgent {
        id: agent
    }

    Component.onCompleted: {
        agent.setup(win)
        agent.setTitleBar(dragStrip)
        agent.setSystemButton(WindowAgent.Minimize, minimizeButton)
        agent.setSystemButton(WindowAgent.Close, closeButton)
        agent.setHitTestVisible(languageBox, true)
        agent.setWindowAttribute("dark-mode", true)
        visible = true
        if (mode === "update")
            Setup.start()
    }

    // an update ends on its own: Flux opens again
    Connections {
        target: Setup
        function onStateChanged() {
            if (Setup.state === "done") {
                win.page = "done"
                if (win.mode === "update") {
                    Setup.launchFlux()
                    closeTimer.start()
                }
            }
        }
    }
    Timer {
        id: closeTimer
        interval: 1600
        onTriggered: Setup.finish()
    }

    onClosing: close => {
        // closing mid-way would leave half a Flux
        if (Setup.state === "working")
            close.accepted = false
        else
            Setup.finish()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ===== The brand pane =====
        Rectangle {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            color: c.pane
            clip: true

            // a soft light behind the logo
            Rectangle {
                width: 420
                height: 420
                x: -110
                y: -170
                radius: width / 2
                opacity: 0.55
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.20) }
                    GradientStop { position: 0.6; color: Qt.rgba(167 / 255, 139 / 255, 250 / 255, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.45; to: 0.7; duration: 3200; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.7; to: 0.45; duration: 3200; easing.type: Easing.InOutSine }
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: c.border
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                anchors.topMargin: 52
                spacing: 0

                Logo {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                }
                Row {
                    Layout.topMargin: 20
                    spacing: 7
                    Text {
                        text: "Flux"
                        color: c.text
                        font.family: c.font
                        font.pixelSize: 26
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Torrent"
                        color: c.text
                        font.family: c.font
                        font.pixelSize: 26
                        font.weight: Font.Light
                    }
                }
                Rectangle {
                    Layout.topMargin: 10
                    implicitWidth: versionText.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: c.border
                    Text {
                        id: versionText
                        anchors.centerIn: parent
                        text: "v" + Setup.version
                        color: c.dim
                        font.family: c.mono
                        font.pixelSize: 11
                    }
                }

                // the steps
                ColumnLayout {
                    Layout.topMargin: 40
                    spacing: 14
                    Repeater {
                        model: win.steps
                        delegate: RowLayout {
                            id: stepRow
                            required property var modelData
                            required property int index
                            readonly property int current: win.steps.findIndex(s => s[0] === win.page)
                            readonly property bool passed: index < current
                            readonly property bool active: index === current
                            spacing: 12
                            Rectangle {
                                implicitWidth: 22
                                implicitHeight: 22
                                radius: 11
                                color: stepRow.active ? c.primary : stepRow.passed ? Qt.rgba(74 / 255, 222 / 255, 128 / 255, 0.16) : "transparent"
                                border.width: stepRow.active || stepRow.passed ? 0 : 1
                                border.color: c.input
                                Behavior on color { ColorAnimation { duration: 220 } }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !stepRow.passed
                                    text: stepRow.index + 1
                                    color: stepRow.active ? c.primaryText : c.faint
                                    font.family: c.mono
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                Glyph {
                                    anchors.centerIn: parent
                                    visible: stepRow.passed
                                    path: "M5 12.5l4.5 4.5L19 7.5"
                                    size: 13
                                    stroke: c.green
                                    lineWidth: 2.4
                                }
                            }
                            Text {
                                text: win.t(stepRow.modelData[1])
                                color: stepRow.active ? c.text : stepRow.passed ? c.dim : c.faint
                                font.family: c.font
                                font.pixelSize: 14
                                font.weight: stepRow.active ? Font.Medium : Font.Normal
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // the language of this setup
                ComboBox {
                    id: languageBox
                    objectName: "languageBox"
                    Layout.preferredWidth: 180
                    implicitHeight: 32
                    model: S.languages
                    textRole: "name"
                    valueRole: "code"
                    currentIndex: S.languages.findIndex(l => l.code === win.lang)
                    onActivated: index => Setup.language = S.languages[index].code
                    Accessible.name: win.t("language")
                    contentItem: Row {
                        leftPadding: 10
                        spacing: 8
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            path: "M5 8l6 6M4 14l6-6 2-3M2 5h12M7 2h1M22 22l-5-10-5 10M14 18h6"
                            size: 14
                            stroke: c.dim
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: languageBox.displayText
                            color: c.dim
                            font.family: c.font
                            font.pixelSize: 13
                        }
                    }
                    indicator: Glyph {
                        x: languageBox.width - width - 10
                        anchors.verticalCenter: parent.verticalCenter
                        path: "M6 9l6 6 6-6"
                        size: 14
                        stroke: c.faint
                    }
                    background: Rectangle {
                        radius: 8
                        color: languageBox.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border.width: 1
                        border.color: languageBox.popup.visible ? c.faint : c.border
                    }
                    delegate: ItemDelegate {
                        id: langItem
                        required property var modelData
                        required property int index
                        width: languageBox.width - 8
                        x: 4
                        height: 30
                        contentItem: Text {
                            text: langItem.modelData.name
                            color: c.text
                            font.family: c.font
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: langItem.highlighted || langItem.hovered ? c.muted : "transparent"
                        }
                        highlighted: languageBox.highlightedIndex === index
                    }
                    popup: Popup {
                        y: -implicitHeight - 6
                        width: languageBox.width
                        implicitHeight: contentItem.implicitHeight + 8
                        padding: 4
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: languageBox.popup.visible ? languageBox.delegateModel : null
                            currentIndex: languageBox.highlightedIndex
                        }
                        background: Rectangle {
                            radius: 10
                            color: c.card
                            border.width: 1
                            border.color: c.border
                        }
                    }
                }
            }
        }

        // ===== The page =====
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // the drag strip, with the window's buttons
            Item {
                id: dragStrip
                anchors.left: parent.left
                anchors.right: parent.right
                height: 44
                Row {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    WindowButton {
                        id: minimizeButton
                        path: "M6 12h12"
                        onClicked: win.showMinimized()
                    }
                    WindowButton {
                        id: closeButton
                        path: "M7 7l10 10M17 7L7 17"
                        danger: true
                        enabled: Setup.state !== "working"
                        onClicked: win.close()
                    }
                }
            }

            Item {
                id: pages
                anchors.fill: parent
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                anchors.topMargin: 56
                anchors.bottomMargin: 88

                Slot { name: "welcome"; WelcomePage {} }
                Slot { name: "options"; OptionsPage {} }
                Slot { name: "progress"; ProgressPage {} }
                Slot { name: "done"; DonePage {} }
                Slot { name: "confirm"; ConfirmPage {} }
            }

            // the buttons
            RowLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 44
                anchors.rightMargin: 44
                anchors.bottomMargin: 32
                spacing: 10

                Item { Layout.fillWidth: true }
                Btn {
                    objectName: "backButton"
                    visible: win.page === "options"
                    variant: "ghost"
                    text: win.t("button.back")
                    onClicked: win.page = "welcome"
                }
                Btn {
                    objectName: "cancelButton"
                    visible: win.page === "welcome" || win.page === "options" || win.page === "confirm"
                    variant: "outline"
                    text: win.t("button.cancel")
                    onClicked: win.close()
                }
                Btn {
                    objectName: "nextButton"
                    visible: win.page === "welcome"
                    text: win.t("button.next")
                    onClicked: win.page = "options"
                }
                Btn {
                    objectName: "installButton"
                    visible: win.page === "options"
                    enabled: Setup.targetProblem === ""
                    text: win.t("button.install")
                    iconPath: "M12 4v11M7 10l5 5 5-5M5 20h14"
                    onClicked: { win.page = "progress"; Setup.start() }
                }
                Btn {
                    objectName: "removeButton"
                    visible: win.page === "confirm"
                    variant: "danger"
                    text: win.t("button.remove")
                    onClicked: { win.page = "progress"; Setup.start() }
                }
                Btn {
                    objectName: "retryButton"
                    visible: win.page === "progress" && (Setup.state === "failed" || Setup.state === "fluxRunning")
                    variant: "outline"
                    text: win.t("button.retry")
                    onClicked: Setup.start()
                }
                Btn {
                    objectName: "closeFluxButton"
                    visible: win.page === "progress" && Setup.state === "fluxRunning"
                    text: win.t("running.close")
                    onClicked: Setup.closeFlux()
                }
                Btn {
                    objectName: "finishButton"
                    visible: win.page === "done" && win.mode !== "update"
                    text: win.mode === "uninstall" ? win.t("button.close") : win.t("button.finish")
                    onClicked: {
                        if (win.mode === "install" && win.launchAfter)
                            Setup.launchFlux()
                        Setup.finish()
                    }
                }
            }
        }
    }

    // ===== Pages =====

    component Slot: Item {
        id: pg
        property string name
        anchors.fill: parent
        readonly property bool shown: win.page === name
        visible: opacity > 0
        opacity: shown ? 1 : 0
        transform: Translate { x: pg.shown ? 0 : 18; Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    component Title: Text {
        Layout.fillWidth: true
        color: c.text
        font.family: c.font
        font.pixelSize: 26
        font.weight: Font.DemiBold
        font.letterSpacing: -0.4
        wrapMode: Text.Wrap
    }
    component Body: Text {
        Layout.fillWidth: true
        color: c.dim
        font.family: c.font
        font.pixelSize: 14
        lineHeight: 1.35
        wrapMode: Text.Wrap
    }

    component WelcomePage: ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Title { text: win.t("welcome.title") }
        Body {
            Layout.topMargin: 12
            text: Setup.installedVersion !== "" ? win.t("welcome.reinstall", Setup.installedVersion, Setup.version) : win.t("welcome.text")
        }
        ColumnLayout {
            Layout.topMargin: 28
            Layout.fillWidth: true
            spacing: 14
            Feature { icon: "M7 4.5v15l12.5-7.5z"; tint: c.blue; title: win.t("feature.watch"); text: win.t("feature.watch.text"); delay: 120 }
            Feature { icon: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4"; tint: c.violet; title: win.t("feature.search"); text: win.t("feature.search.text"); delay: 220 }
            Feature { icon: "M4 8h13l-3-3M20 16H7l3 3"; tint: c.green; title: win.t("feature.migrate"); text: win.t("feature.migrate.text"); delay: 320 }
        }
        Item { Layout.fillHeight: true }
    }

    component Feature: RowLayout {
        id: feat
        property string icon
        property color tint
        property string title
        property string text
        property int delay
        Layout.fillWidth: true
        spacing: 14
        opacity: 0
        Component.onCompleted: appear.start()
        SequentialAnimation {
            id: appear
            PauseAnimation { duration: feat.delay }
            NumberAnimation { target: feat; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
        }
        Rectangle {
            implicitWidth: 38
            implicitHeight: 38
            radius: 10
            color: Qt.rgba(feat.tint.r, feat.tint.g, feat.tint.b, 0.12)
            border.width: 1
            border.color: Qt.rgba(feat.tint.r, feat.tint.g, feat.tint.b, 0.22)
            Glyph { anchors.centerIn: parent; path: feat.icon; size: 18; stroke: feat.tint }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: feat.title; color: c.text; font.family: c.font; font.pixelSize: 14; font.weight: Font.Medium }
            Text { Layout.fillWidth: true; text: feat.text; color: c.dim; font.family: c.font; font.pixelSize: 13; elide: Text.ElideRight }
        }
    }

    component OptionsPage: ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Title { text: win.t("options.title") }
        Body { Layout.topMargin: 10; text: win.t("options.text") }

        Text {
            Layout.topMargin: 26
            text: win.t("options.folder")
            color: c.text
            font.family: c.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        RowLayout {
            Layout.topMargin: 8
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: folderField
                objectName: "folderField"
                Layout.fillWidth: true
                implicitHeight: 36
                text: Setup.targetDir
                onEditingFinished: Setup.targetDir = text
                color: c.text
                font.family: c.font
                font.pixelSize: 13
                leftPadding: 12
                selectByMouse: true
                selectionColor: Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.4)
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.045)
                    border.width: 1
                    border.color: folderField.activeFocus ? c.faint : c.input
                }
            }
            Btn {
                variant: "outline"
                text: win.t("options.browse")
                onClicked: Setup.browse()
            }
        }
        Text {
            Layout.topMargin: 8
            Layout.fillWidth: true
            text: Setup.targetProblem !== "" ? win.t("problem." + Setup.targetProblem)
                                             : win.t("options.space", win.size(Setup.requiredBytes), win.size(Setup.freeBytes))
            color: Setup.targetProblem !== "" ? c.error : c.faint
            font.family: c.font
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        ColumnLayout {
            Layout.topMargin: 22
            Layout.fillWidth: true
            spacing: 4
            Toggle { text: win.t("options.desktop"); checked: Setup.desktopShortcut; onToggled: Setup.desktopShortcut = checked }
            Toggle { text: win.t("options.torrents"); checked: Setup.associateTorrents; onToggled: Setup.associateTorrents = checked }
            Toggle { text: win.t("options.magnets"); checked: Setup.associateMagnets; onToggled: Setup.associateMagnets = checked }
        }
        Item { Layout.fillHeight: true }
    }

    component ProgressPage: ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Title {
            text: Setup.state === "fluxRunning" ? win.t("running.title")
                : Setup.state === "failed" ? win.t("failed.title")
                : win.mode === "uninstall" ? win.t("remove.working")
                : win.mode === "update" ? win.t("update.title", Setup.version)
                : win.t("install.title")
        }
        Body {
            Layout.topMargin: 10
            visible: Setup.state === "fluxRunning" || Setup.state === "failed"
            text: Setup.state === "fluxRunning" ? win.t("running.text") : win.t("failed.text")
        }
        Text {
            Layout.topMargin: 6
            Layout.fillWidth: true
            visible: Setup.state === "failed"
            text: Setup.error
            color: c.error
            font.family: c.mono
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
        }

        Item { Layout.fillHeight: true }

        Text {
            visible: Setup.state === "working"
            text: Math.round(Setup.progress * 100) + "%"
            color: c.text
            font.family: c.font
            font.pixelSize: 48
            font.weight: Font.Light
            font.letterSpacing: -1
            font.features: { "tnum": 1 }
        }
        Bar {
            Layout.topMargin: 14
            Layout.fillWidth: true
            value: Setup.progress
            running: Setup.state === "working"
            tint: Setup.state === "failed" ? c.error : Setup.state === "fluxRunning" ? c.warn : c.blue
        }
        Text {
            Layout.topMargin: 10
            Layout.fillWidth: true
            text: Setup.state !== "working" ? ""
                : Setup.currentFile !== "" ? win.t("install.copying", Setup.currentFile)
                : win.t("install.finishing")
            color: c.faint
            font.family: c.mono
            font.pixelSize: 11
            elide: Text.ElideMiddle
        }
        Item { Layout.preferredHeight: 8 }
    }

    component DonePage: ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Check {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            drawing: win.page === "done"
        }
        Title {
            Layout.topMargin: 24
            text: win.mode === "uninstall" ? win.t("removed.title") : win.mode === "update" ? win.t("updated.title", Setup.version) : win.t("done.title")
        }
        Body {
            Layout.topMargin: 10
            text: win.mode === "uninstall" ? win.t("removed.text") : win.mode === "update" ? win.t("updated.text") : win.t("done.text")
        }
        Toggle {
            Layout.topMargin: 22
            visible: win.mode === "install"
            text: win.t("done.launch")
            checked: win.launchAfter
            onToggled: win.launchAfter = checked
        }
        Item { Layout.fillHeight: true }
    }

    component ConfirmPage: ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Title { text: win.t("uninstall.title") }
        Body { Layout.topMargin: 12; text: win.t("uninstall.text", Setup.installedVersion !== "" ? Setup.installedVersion : Setup.version) }
        Toggle {
            Layout.topMargin: 24
            text: win.t("uninstall.data")
            checked: Setup.removeUserData
            onToggled: Setup.removeUserData = checked
        }
        Item { Layout.fillHeight: true }
    }

    // ===== Controls =====

    // A line icon on a 24 grid (Flux's icons are drawn the same way)
    component Glyph: Item {
        id: glyph
        property string path
        property real size: 16
        property color stroke: c.text
        property real lineWidth: 2
        implicitWidth: size
        implicitHeight: size
        Shape {
            width: 24
            height: 24
            scale: glyph.size / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: glyph.stroke
                strokeWidth: glyph.lineWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: glyph.path }
            }
        }
    }

    // Flux's logo: the wave draws itself on the tile
    component Logo: Rectangle {
        id: logo
        radius: width * 0.25
        color: "#FAFAFA"
        property real drawn: 0
        NumberAnimation on drawn { from: 0; to: 1; duration: 1100; easing.type: Easing.InOutCubic }
        Shape {
            width: 24
            height: 24
            scale: logo.width / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#0A0A0A"
                strokeWidth: 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                strokeStyle: ShapePath.DashLine
                // a dash as long as the wave, moved in from its end
                dashPattern: [16, 16]
                dashOffset: 16 * (1 - logo.drawn)
                PathSvg { path: "M3 8c4.5 0 4.5 8 9 8s4.5-8 9-8" }
            }
        }
    }

    // A tick in a circle that draws itself
    component Check: Item {
        id: check
        property bool drawing: false
        property real drawn: 0
        onDrawingChanged: if (drawing) drawAnim.restart()
        NumberAnimation { id: drawAnim; target: check; property: "drawn"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(74 / 255, 222 / 255, 128 / 255, 0.12)
            border.width: 1
            border.color: Qt.rgba(74 / 255, 222 / 255, 128 / 255, 0.3)
            scale: 0.85 + 0.15 * check.drawn
        }
        Shape {
            width: 24
            height: 24
            scale: check.width / 24
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: c.green
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                strokeStyle: ShapePath.DashLine
                dashPattern: [8, 8]
                dashOffset: 8 * (1 - check.drawn)
                PathSvg { path: "M7.5 12.5l3 3 6-6.5" }
            }
        }
    }

    component Btn: AbstractButton {
        id: btn
        // "primary", "outline", "ghost", "danger"
        property string variant: "primary"
        property string iconPath
        implicitHeight: 38
        implicitWidth: Math.max(96, row.implicitWidth + 32)
        opacity: enabled ? 1 : 0.45
        focusPolicy: Qt.StrongFocus
        Accessible.name: text
        background: Rectangle {
            radius: 8
            color: btn.variant === "primary" ? (btn.down ? "#D4D4D4" : btn.hovered ? "#F5F5F5" : c.primary)
                 : btn.variant === "danger" ? (btn.hovered ? "#FF7A7C" : c.error)
                 : btn.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            border.width: btn.variant === "outline" ? 1 : 0
            border.color: c.input
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                visible: btn.visualFocus
                anchors.fill: parent
                anchors.margins: -3
                radius: 11
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.35)
            }
        }
        contentItem: Item {
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8
                Glyph {
                    visible: btn.iconPath !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    path: btn.iconPath
                    size: 15
                    stroke: label.color
                }
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: btn.text
                    color: btn.variant === "primary" ? c.primaryText : btn.variant === "danger" ? "#FFFFFF" : c.text
                    font.family: c.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }
        }
        Keys.onReturnPressed: clicked()
    }

    // A switch with its label, like Flux's settings
    component Toggle: AbstractButton {
        id: tg
        checkable: true
        Layout.fillWidth: true
        implicitHeight: 38
        Accessible.role: Accessible.CheckBox
        Accessible.name: text
        contentItem: RowLayout {
            spacing: 12
            Rectangle {
                implicitWidth: 34
                implicitHeight: 20
                radius: 10
                color: tg.checked ? c.primary : c.muted
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    y: 3
                    x: tg.checked ? parent.width - width - 3 : 3
                    color: tg.checked ? c.primaryText : c.dim
                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                Layout.fillWidth: true
                text: tg.text
                color: c.text
                font.family: c.font
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }
        background: Item {}
    }

    // Flux's progress bar: the fill, with a shimmer running over it while busy
    component Bar: Item {
        id: bar
        property real value: 0
        property bool running: false
        property color tint: c.blue
        implicitHeight: 6
        Rectangle {
            anchors.fill: parent
            radius: 3
            color: c.muted
        }
        Rectangle {
            id: fill
            height: parent.height
            radius: 3
            width: Math.max(height, parent.width * Math.min(1, bar.value))
            color: bar.tint
            clip: true
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
            Rectangle {
                visible: bar.running
                width: 90
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                NumberAnimation on x {
                    running: bar.running
                    loops: Animation.Infinite
                    from: -90
                    to: Math.max(fill.width, 200)
                    duration: 1300
                }
            }
        }
    }

    component WindowButton: AbstractButton {
        id: wb
        property string path
        property bool danger: false
        implicitWidth: 46
        implicitHeight: 34
        opacity: enabled ? 1 : 0.35
        background: Rectangle {
            color: wb.hovered ? (wb.danger ? "#C42B1C" : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        }
        contentItem: Item {
            Glyph { anchors.centerIn: parent; path: wb.path; size: 15; lineWidth: 1.6; stroke: c.text }
        }
    }
}
