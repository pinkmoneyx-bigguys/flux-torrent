import QtQuick
import QtQuick.Shapes
import Flux

// Download and upload rates over the last two minutes: two smooth filled curves that scroll on every
// display frame (not once a second), so the newest sample slides in from the right edge while the
// next one is on its way. The scale eases to a new peak instead of jumping. Hovering shows the rates
// under the pointer. Samples come from TorrentListModel's history; `torrentId` "" is all torrents.
Item {
    id: graph

    property string torrentId
    // samples across the width
    property int span: 120
    readonly property int interval: TorrentListModel.historyInterval

    property var down: []
    property var up: []
    readonly property real lastDown: down.length > 0 ? down[down.length - 1] : 0
    readonly property real lastUp: up.length > 0 ? up[up.length - 1] : 0

    // 0..1: how far the clock is towards the next sample; moves the curves left by that part of a step
    property real phase: 0
    // the top of the scale: a round figure above the highest rate in view, eased
    property real peak: 64 * 1024
    property real shownPeak: peak
    Behavior on shownPeak {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
    }

    readonly property real step: plot.width / Math.max(1, span - 1)

    // What fits: the legend and the time line need height; the scale labels need room between grid
    // lines (all three, only the top one, or none) and a column on the right
    readonly property bool showLegend: height >= 120
    readonly property bool showTime: height >= 84
    readonly property int scaleLabels: width < 220 ? 0 : plot.height >= 96 ? 3 : plot.height >= 34 ? 1 : 0
    // solid behind the hover card and the dots (the glass background is see-through)
    readonly property color cardColor: Theme.glass ? "#16161C" : Theme.background

    // A round figure in the units the labels use (KiB, MiB…: powers of 1024), so the scale reads 30 MiB/s
    function niceCeil(v) {
        const unit = Math.pow(1024, Math.floor(Math.log(Math.max(v, 1)) / Math.log(1024)))
        const x = v / unit
        const base = Math.pow(10, Math.floor(Math.log10(Math.max(x, 1))))
        for (const u of [1, 1.5, 2, 3, 4, 5, 6, 8, 10]) {
            if (u * base >= x)
                return u * base * unit
        }
        return 10 * base * unit
    }

    function currentPhase() {
        return Theme.reducedMotion ? 1
             : Math.max(0, Math.min(1, (Date.now() - TorrentListModel.historySampledAt) / interval))
    }

    function reload() {
        const h = TorrentListModel.speedHistory(torrentId)
        // the shift and the new curves change in the same frame: the old shift on the new curves
        // would show every point one step too far left for a frame
        phase = currentPhase()
        down = h.down.slice(-(span + 2))
        up = h.up.slice(-(span + 2))
        let m = 0
        for (const v of down)
            m = Math.max(m, v)
        for (const v of up)
            m = Math.max(m, v)
        // the scale grows at once when a rate needs it, and shrinks only when it is far too tall,
        // so it does not breathe with every sample
        const wanted = niceCeil(Math.max(m * 1.12, 16 * 1024))
        if (wanted > peak || wanted < peak * 0.45)
            peak = wanted
    }

    Connections {
        target: TorrentListModel
        function onHistorySampled() {
            graph.reload()
        }
    }
    onTorrentIdChanged: reload()
    Component.onCompleted: reload()

    FrameAnimation {
        running: graph.visible
        onTriggered: graph.phase = graph.currentPhase()
    }

    // x of sample i of n: the newest sits two steps past the right edge when it arrives. A new sample
    // reshapes the curve between the two before it; that piece is still out of view then.
    function xAt(i, n) {
        return plot.width + 2 * step - (n - 1 - i) * step
    }
    function yAt(v) {
        return plot.height - Math.min(1, v / Math.max(1, shownPeak)) * (plot.height - 2)
    }
    // A Catmull-Rom curve through the samples as SVG cubic segments
    readonly property string downCurve: curve(down)
    readonly property string upCurve: curve(up)
    // the same, dropped to the bottom and closed, for the fill
    function closedCurve(d, values) {
        const n = values.length
        if (n < 2)
            return ""
        return d + " L " + xAt(n - 1, n).toFixed(2) + " " + plot.height + " L " + xAt(0, n).toFixed(2) + " " + plot.height + " Z"
    }
    function curve(values) {
        const n = values.length
        if (n < 2)
            return ""
        const pts = []
        for (let i = 0; i < n; ++i)
            pts.push({ x: xAt(i, n), y: yAt(values[i]) })
        let d = "M " + pts[0].x.toFixed(2) + " " + pts[0].y.toFixed(2)
        for (let i = 0; i < n - 1; ++i) {
            const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(n - 1, i + 2)]
            // tension 0.5; control points kept inside the plot so the curve never dips below zero
            const c1x = p1.x + (p2.x - p0.x) / 6, c1y = Math.min(plot.height, p1.y + (p2.y - p0.y) / 6)
            const c2x = p2.x - (p3.x - p1.x) / 6, c2y = Math.min(plot.height, p2.y - (p3.y - p1.y) / 6)
            d += " C " + c1x.toFixed(2) + " " + c1y.toFixed(2) + " " + c2x.toFixed(2) + " " + c2y.toFixed(2)
                 + " " + p2.x.toFixed(2) + " " + p2.y.toFixed(2)
        }
        return d
    }

    // --- Legend ---------------------------------------------------------------------------------
    Row {
        id: legend
        x: 0
        y: 0
        visible: graph.showLegend
        height: visible ? implicitHeight : 0
        spacing: Theme.sp(5)

        Repeater {
            model: [
                { label: qsTr("Download"), color: Theme.download, value: graph.lastDown },
                { label: qsTr("Upload"), color: Theme.upload, value: graph.lastUp }
            ]
            Row {
                required property var modelData
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: modelData.color
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                }
                RollingText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Format.speed(modelData.value)
                    value: modelData.value
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
            }
        }
    }

    // --- Plot -----------------------------------------------------------------------------------
    Item {
        id: plot
        objectName: "speedPlot"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: graph.scaleLabels > 0 ? 76 : 0
        anchors.top: legend.bottom
        anchors.topMargin: graph.showLegend ? Theme.sp(3) : 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: graph.showTime ? 18 : 2
        clip: true

        // grid: the top of the scale and two lines under it
        Repeater {
            model: 3
            Rectangle {
                required property int index
                y: Math.round(plot.height * index / 3)
                width: plot.width
                height: 1
                color: Theme.border
                opacity: index === 0 ? 1 : 0.6
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.border
        }

        // the curves scroll as one piece; only the shift changes between samples
        Item {
            id: scroller
            width: plot.width
            height: plot.height
            x: -graph.phase * graph.step

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: plot.height
                        GradientStop { position: 0; color: Theme.alpha(Theme.upload, 0.28) }
                        GradientStop { position: 1; color: Theme.alpha(Theme.upload, 0) }
                    }
                    PathSvg { path: graph.closedCurve(graph.upCurve, graph.up) }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 0; x2: 0; y2: plot.height
                        GradientStop { position: 0; color: Theme.alpha(Theme.download, 0.32) }
                        GradientStop { position: 1; color: Theme.alpha(Theme.download, 0) }
                    }
                    PathSvg { path: graph.closedCurve(graph.downCurve, graph.down) }
                }
                ShapePath {
                    strokeColor: Theme.upload
                    strokeWidth: 1.75
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: graph.upCurve }
                }
                ShapePath {
                    strokeColor: Theme.download
                    strokeWidth: 2
                    fillColor: "transparent"
                    joinStyle: ShapePath.RoundJoin
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: graph.downCurve }
                }
            }
        }

        // --- Hover: a line and the rates under the pointer ----------------------------------------
        HoverHandler {
            id: hover
        }
        readonly property int hoverIndex: {
            if (!hover.hovered || graph.down.length < 2)
                return -1
            const n = graph.down.length
            const fromRight = (plot.width + graph.step - graph.phase * graph.step - hover.point.position.x) / graph.step
            const i = n - 1 - Math.round(fromRight)
            return i >= 0 && i < n ? i : -1
        }
        Rectangle {
            visible: plot.hoverIndex >= 0
            x: plot.hoverIndex >= 0 ? graph.xAt(plot.hoverIndex, graph.down.length) - graph.phase * graph.step : 0
            width: 1
            height: plot.height
            color: Theme.alpha(Theme.text, 0.35)

            Rectangle {
                width: 8
                height: 8
                radius: 4
                x: -3.5
                y: plot.hoverIndex >= 0 ? graph.yAt(graph.down[plot.hoverIndex]) - 4 : 0
                color: Theme.download
                border.width: 2
                border.color: graph.cardColor
            }
            Rectangle {
                width: 8
                height: 8
                radius: 4
                x: -3.5
                y: plot.hoverIndex >= 0 ? graph.yAt(graph.up[plot.hoverIndex]) - 4 : 0
                color: Theme.upload
                border.width: 2
                border.color: graph.cardColor
            }
        }
        Rectangle {
            id: hoverCard
            visible: plot.hoverIndex >= 0 && plot.height >= height + 8
            readonly property real lineX: plot.hoverIndex >= 0 ? graph.xAt(plot.hoverIndex, graph.down.length) - graph.phase * graph.step : 0
            x: lineX + 12 + width > plot.width ? lineX - 12 - width : lineX + 12
            y: 8
            width: cardColumn.implicitWidth + 20
            height: cardColumn.implicitHeight + 14
            radius: Theme.radiusCtl
            color: graph.cardColor
            border.width: 1
            border.color: Theme.border

            Column {
                id: cardColumn
                x: 10
                y: 7
                spacing: 3
                Text {
                    text: plot.hoverIndex >= 0 ? qsTr("%1 s ago").arg(graph.down.length - 1 - plot.hoverIndex) : ""
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: 11
                }
                Text {
                    text: "↓ " + Format.speed(plot.hoverIndex >= 0 ? graph.down[plot.hoverIndex] : 0)
                    color: Theme.download
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
                Text {
                    text: "↑ " + Format.speed(plot.hoverIndex >= 0 ? graph.up[plot.hoverIndex] : 0)
                    color: Theme.upload
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                }
            }
        }
    }

    // scale labels on the right, at the grid lines (as many as fit)
    Repeater {
        model: graph.scaleLabels
        Text {
            required property int index
            x: plot.x + plot.width + 10
            y: plot.y + Math.round(plot.height * index / 3) - height / 2
            text: Format.speed(graph.shownPeak * (3 - index) / 3)
            color: Theme.textFaint
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }
    // time under the plot
    Text {
        visible: graph.showTime
        x: plot.x
        y: plot.y + plot.height + 4
        text: qsTr("%1 min ago").arg(Math.round(graph.span * graph.interval / 60000))
        color: Theme.textFaint
        font.family: Theme.fontText
        font.pixelSize: 11
    }
    Text {
        visible: graph.showTime
        x: plot.x + plot.width - width
        y: plot.y + plot.height + 4
        text: qsTr("now")
        color: Theme.textFaint
        font.family: Theme.fontText
        font.pixelSize: 11
    }
}
