import QtQuick
import Flux

// shadcn Progress: a rounded track (indicator colour at 20 %) with the indicator. value 0..1.
Item {
    id: root

    property real value: 0
    property color color: Theme.primary

    implicitWidth: 120
    implicitHeight: 6

    Accessible.role: Accessible.ProgressBar
    Accessible.name: Math.round(value * 100) + "%"

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(root.color, 0.2)
    }
    Rectangle {
        width: Math.max(root.value > 0 ? height : 0, parent.width * Math.min(1, Math.max(0, root.value)))
        height: parent.height
        radius: height / 2
        color: root.color
    }
}
