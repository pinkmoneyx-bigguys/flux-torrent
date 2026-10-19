import QtQuick
import QtQuick.Controls.Basic
import Flux

// A row of pill-shaped options; the selected one is a lighter pill with a top highlight.
// Arrow keys move the selection (the control is a single Tab stop).
Item {
    id: root

    property var model: []        // array of strings
    property int currentIndex: 0
    signal activated(int index)

    implicitWidth: row.implicitWidth + 2 * row.x
    implicitHeight: 34

    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Options")

    // The i-th segment button, or null: for tests and for callers that need to anchor to it
    // Keyboard selection (arrows, Space) is never animated. The flag goes up on key-down and drops on the
    // turn after the key-up was handled (Space selects on release), or when no segment keeps the focus.
    property bool _kbd: false

    function _isSelectKey(key) {
        return key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Space
    }

    function _releaseKbdLater() {
        Qt.callLater(() => root._kbd = false)
    }

    function _anySegmentFocused() {
        for (let i = 0; i < repeater.count; ++i) {
            if (repeater.itemAt(i).activeFocus)
                return true
        }
        return false
    }

    function itemAt(i) {
        return repeater.itemAt(i)
    }

    function _pick(i) {
        if (i < 0 || i >= repeater.count)
            return
        currentIndex = i
        activated(i)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Row {
        id: row
        x: 2
        y: 2
        height: root.height - 4
        spacing: 0

        Repeater {
            id: repeater
            model: root.model

            delegate: AbstractButton {
                id: seg

                required property int index
                required property var modelData

                readonly property bool selected: index === root.currentIndex

                text: String(modelData)
                checked: selected // not checkable: a click never flips it, the binding stays intact
                height: row.height
                implicitWidth: label.implicitWidth + Theme.sp(7)
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus

                Accessible.role: Accessible.RadioButton
                Accessible.name: text
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.onPressAction: seg.clicked()

                onClicked: root._pick(index)

                Keys.onPressed: event => { // Space only: arrows are taken by the specific handlers below
                    if (event.key === Qt.Key_Space && !event.isAutoRepeat)
                        root._kbd = true
                }
                Keys.onReleased: event => {
                    if (root._isSelectKey(event.key) && !event.isAutoRepeat)
                        root._releaseKbdLater()
                }
                // focus moves between segments while an arrow is down: only drop the flag when it left them all
                onActiveFocusChanged: {
                    if (!activeFocus)
                        Qt.callLater(() => { if (!root._anySegmentFocused()) root._kbd = false })
                }

                Keys.onLeftPressed: event => root._move(index - 1)
                Keys.onRightPressed: event => root._move(index + 1)

                background: Item {
                    property alias color: pillBg.color

                    Rectangle {
                        id: pillBg
                        anchors.fill: parent
                        radius: height / 2
                        color: seg.selected ? Qt.rgba(1, 1, 1, 0.14)
                                            : Qt.rgba(1, 1, 1, seg.hovered ? 0.06 : 0)
                        Behavior on color {
                            enabled: !Theme.reducedMotion && !root._kbd
                            ColorAnimation { duration: Theme.durFast }
                        }
                    }
                    Rectangle { // inset top highlight of the selected pill
                        visible: seg.selected
                        x: pillBg.radius - Math.sqrt(Math.max(0, 2 * pillBg.radius - 1))
                        width: parent.width - 2 * x
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.16)
                    }
                    Rectangle {
                        visible: seg.visualFocus
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: height / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                    }
                }

                contentItem: Text {
                    id: label
                    text: seg.text
                    color: seg.selected ? Theme.text : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: 13
                    font.weight: seg.selected ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.NoWrap
                }
            }
        }
    }

    function _move(i) {
        if (i < 0 || i >= repeater.count)
            return
        _kbd = true // the specific arrow handlers run before Keys.onPressed, so raise the flag here
        _pick(i)
        repeater.itemAt(i).forceActiveFocus(Qt.TabFocusReason)
    }
}
