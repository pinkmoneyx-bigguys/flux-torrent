import QtQuick
import Flux

// A themed container: the one place that decides how a surface looks in each look, so the shell and
// pages never hard-code glass. Children go into the content item.
//   kind "panel"  — glass: frosted pane;  default: card (#171717, 1 px border)
//   kind "inset"  — glass: nothing;       default: the content inset (background, border, xl radius)
//   kind "chrome" — glass: frosted pane;  default: nothing, it sits flat on the window chrome
//   kind "field"  — glass: frosted pill;  default: an input box (input/30 fill, input border)
Item {
    id: root

    property string kind: "panel"
    property real radius: kind === "field" && Theme.glass ? height / 2 : Theme.radiusPanel
    // Glass only: the soft drop shadow under the pane
    property bool shadow: true
    // Default look only: draw the focus ring (fields)
    property bool focused: false
    default property alias content: contentItem.data

    readonly property bool _glass: Theme.glass && kind !== "inset"
    // Cards and the inset draw their border over the content, 1 px in from it: rows and headers that run
    // edge to edge would otherwise paint over the sides and break the outline
    readonly property bool _outlined: !Theme.glass && (kind === "inset" || kind === "panel")

    Loader {
        anchors.fill: parent
        active: root._glass
        sourceComponent: GlassPanel {
            radius: root.radius
            shadow: root.shadow && root.kind !== "field"
        }
    }

    // shadcn: shadow-sm of the inset
    Rectangle {
        visible: !root._glass && root.kind === "inset"
        anchors.fill: parent
        anchors.topMargin: 1
        anchors.bottomMargin: -1
        radius: root.radius
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    Rectangle {
        visible: !root._glass && root.kind !== "chrome"
        anchors.fill: parent
        radius: root.radius
        color: root.kind === "inset" ? Theme.background
             : root.kind === "field" ? Theme.inputFill
             : Theme.card
        border.width: root._outlined ? 0 : 1
        border.color: root.kind === "field" ? (root.focused ? Theme.ring : Theme.input) : Theme.border
    }

    // focus-visible:ring-[3px] ring-ring/50
    Rectangle {
        visible: !Theme.glass && root.kind === "field" && root.focused
        anchors.fill: parent
        anchors.margins: -3
        radius: root.radius + 3
        color: "transparent"
        border.width: 3
        border.color: Theme.alpha(Theme.ring, 0.5)
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root._outlined ? 1 : 0
    }

    Rectangle {
        visible: root._outlined
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.border
    }
}
