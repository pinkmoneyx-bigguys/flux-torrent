import QtQuick
import QtQuick.Controls.Basic
import Flux

// shadcn Tooltip: a small primary-coloured label that fades and grows in after a short delay.
// Use inside the item it describes: UiTooltip { text: …; shown: hoverHandler.hovered }
// `placement`: "top" (default), "bottom" (title bar) or "right" (folded sidebar).
ToolTip {
    id: root

    property bool shown: false
    property string placement: "top"

    visible: shown && text !== ""
    delay: 350
    padding: 0
    topPadding: 5
    bottomPadding: 5
    leftPadding: 10
    rightPadding: 10
    y: placement === "bottom" ? (parent ? parent.height + 6 : 0)
       : placement === "right" ? (parent ? (parent.height - implicitHeight) / 2 : 0)
       : -implicitHeight - 6
    x: placement === "right" ? (parent ? parent.width + 8 : 0) : (parent ? (parent.width - implicitWidth) / 2 : 0)

    background: Rectangle {
        radius: Theme.radiusCtl - 2
        color: Theme.primary
    }
    contentItem: Text {
        text: root.text
        color: Theme.primaryText
        font.family: Theme.fontText
        font.pixelSize: Theme.textXs
        font.weight: Font.Medium
    }

    enter: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durFast; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: Theme.durFast; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        enabled: !Theme.reducedMotion
        NumberAnimation { property: "opacity"; to: 0; duration: 100 }
    }
}
