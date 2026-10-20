import QtQuick
import Flux

// shadcn Progress: a rounded track (indicator colour at 20 %) with the indicator. value 0..1.
// The indicator glides to a new value; `active` (work under way) runs a soft light sweep along it.
Item {
    id: root

    property real value: 0
    property color color: Theme.primary
    property bool active: false

    implicitWidth: 120
    implicitHeight: 6

    Accessible.role: Accessible.ProgressBar
    Accessible.name: Math.round(value * 100) + "%"

    // Counted in Theme while sweeping, so the shared clock runs only when someone looks at it
    readonly property bool _shimmering: active && visible && !Theme.reducedMotion && indicator.width > 2 * height
    property bool _counted: false
    function _count() {
        if (_shimmering === _counted)
            return
        _counted = _shimmering
        Theme.shimmerUsers += _counted ? 1 : -1
    }
    on_ShimmeringChanged: _count()
    Component.onCompleted: _count()
    Component.onDestruction: {
        if (_counted)
            Theme.shimmerUsers -= 1
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.alpha(root.color, 0.2)
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durMed }
        }
    }

    Rectangle {
        id: indicator
        width: Math.max(root.value > 0 ? height : 0, root.width * Math.min(1, Math.max(0, root.value)))
        height: parent.height
        radius: height / 2
        color: root.color

        Behavior on width {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durValue; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            enabled: !Theme.reducedMotion
            ColorAnimation { duration: Theme.durMed }
        }

        // The sweep stays clear of the rounded ends, so clipping never squares them off
        Item {
            anchors.fill: parent
            anchors.leftMargin: indicator.radius
            anchors.rightMargin: indicator.radius
            clip: true
            visible: root._shimmering

            Rectangle {
                id: sheen
                width: Math.max(24, Math.min(64, parent.width * 0.6))
                height: parent.height
                x: -width + Theme.shimmerPhase * (parent.width + width)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.5) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
        }
    }
}
