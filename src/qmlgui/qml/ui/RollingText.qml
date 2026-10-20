import QtQuick
import Flux

// Text whose characters roll like an odometer when they change: each place has its own slot, and only
// a place whose character changed rolls, the new character pushing the old one out (a carousel, no
// fading). Slots count from the right, so the unit stays put when the figure gains a digit. `value`
// (optional) sets the direction: up when it grows, down when it falls. Use a mono font for figures so
// the digits keep their places.
Item {
    id: root

    property string text
    property real value: NaN
    property font font
    property color color: Theme.text
    // Text.AlignLeft or Text.AlignRight
    property int horizontalAlignment: Text.AlignLeft

    // 1: new characters come up from below (growing value), -1: down from above
    property int direction: 1
    property real _lastValue: NaN
    onValueChanged: {
        if (!isNaN(value) && !isNaN(_lastValue) && value !== _lastValue)
            direction = value > _lastValue ? 1 : -1
        _lastValue = value
    }

    implicitWidth: row.implicitWidth
    implicitHeight: metrics.height

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    FontMetrics {
        id: metrics
        font: root.font
    }

    // One entry per place. Places are added and removed at the left end only, so a figure growing a
    // digit ("9,8" → "10,2") keeps every other slot and its state: just the changed characters roll.
    ListModel {
        id: places
    }
    function _syncPlaces() {
        while (places.count < text.length)
            places.append({ place: 0 })
        while (places.count > text.length)
            places.remove(places.count - 1)
    }
    onTextChanged: _syncPlaces()
    Component.onCompleted: _syncPlaces()

    Row {
        id: row
        anchors.right: root.horizontalAlignment === Text.AlignRight ? parent.right : undefined
        anchors.left: root.horizontalAlignment === Text.AlignRight ? undefined : parent.left
        anchors.verticalCenter: parent.verticalCenter
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: places

            // One place, counted from the right
            Item {
                id: slot
                required property int index
                readonly property string ch: {
                    const i = root.text.length - 1 - index
                    return i >= 0 ? root.text.charAt(i) : ""
                }
                property string shown: ""
                property string leaving: ""
                // 0 → 1 while rolling
                property real t: 1
                property int dir: 1

                width: incoming.implicitWidth
                height: metrics.height
                clip: true
                Behavior on width {
                    enabled: !Theme.reducedMotion
                    NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: shown = ch

                onChChanged: {
                    if (ch === shown)
                        return
                    leaving = shown
                    shown = ch
                    dir = root.direction
                    if (Theme.reducedMotion) {
                        t = 1
                        return
                    }
                    roll.restart()
                }
                NumberAnimation {
                    id: roll
                    target: slot
                    property: "t"
                    from: 0
                    to: 1
                    duration: 380
                    easing.type: Easing.OutCubic
                }

                // a carousel: the old character rolls out of the slot as the new one rolls in behind it
                Text {
                    id: outgoing
                    visible: slot.t < 1
                    y: -slot.t * slot.dir * slot.height
                    text: slot.leaving
                    color: root.color
                    font: root.font
                }
                Text {
                    id: incoming
                    y: (1 - slot.t) * slot.dir * slot.height
                    text: slot.shown
                    color: root.color
                    font: root.font
                }
            }
        }
    }
}
