import QtQuick

// The mouse wheel over a Flickable (a list, a grid): each notch moves a goal by `step` and the view eases
// toward it every frame, so notches in a row make one continuous glide instead of a jump each (Qt's own
// steps are small and abrupt). Touchpads keep scrolling as they do. Put it inside the Flickable:
//     ListView { SmoothWheel { step: 200 } }
WheelHandler {
    id: root

    // (declared in a list, a handler lands on its contentItem: the list is above it)
    property Flickable flickable: {
        let item = parent
        while (item && !(item instanceof Flickable))
            item = item.parent
        return item
    }
    property real step: 240
    // a notch moved the view (a dialog that keeps its top in place stops doing so)
    signal scrolled()

    acceptedDevices: PointerDevice.Mouse

    function limit(y) {
        const f = flickable
        const top = f.originY
        const bottom = Math.max(top, f.originY + f.contentHeight - f.height)
        return Math.max(top, Math.min(bottom, y))
    }

    onWheel: event => {
        const from = glide.running ? glide.goal : flickable.contentY
        glide.goal = limit(from - event.angleDelta.y / 120 * step)
        glide.start()
        event.accepted = true
        scrolled()
    }

    property FrameAnimation glide: FrameAnimation {
        property real goal: 0
        onTriggered: {
            const f = root.flickable
            // a drag or a flick takes over; the end may have moved as rows were measured
            if (!f || f.moving) {
                stop()
                return
            }
            goal = root.limit(goal)
            const d = goal - f.contentY
            if (Math.abs(d) < 0.5) {
                f.contentY = goal
                stop()
                return
            }
            f.contentY += d * (1 - Math.exp(-frameTime * 14))
        }
    }
}
