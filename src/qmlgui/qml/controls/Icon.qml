import QtQuick
import QtQuick.Shapes
import Flux

// A stroked SVG path icon. `path` is drawn on a 24x24 grid and scaled to `size`; `strokeWidth`
// is measured in grid units (like SVG's stroke-width with viewBox="0 0 24 24").
Item {
    id: root

    property string path
    property color color: Theme.text
    property real size: 16
    property real strokeWidth: 1.5

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.path }
        }
    }
}
