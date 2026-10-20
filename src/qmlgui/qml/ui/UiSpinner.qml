import QtQuick
import Flux

// A rotating arc for work in progress (lucide loader-circle). With reduced motion it stays still.
Icon {
    id: root

    property bool running: visible

    path: Icons.loader
    size: 16
    strokeWidth: 2
    color: Theme.textDim

    RotationAnimator on rotation {
        running: root.running && !Theme.reducedMotion
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
