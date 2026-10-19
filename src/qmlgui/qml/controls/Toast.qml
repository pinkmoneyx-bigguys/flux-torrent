import QtQuick
import QtQuick.Layouts
import Flux

// A 392 px notification card: icon + title row, then up to a grid of two-column action buttons.
// show() slides it in from 14 px below over 340 ms; hide() fades it out in 150 ms. Both are instant
// with reduced motion. `actions` is an array of { text, primary, onTriggered }.
Item {
    id: root

    property string title
    property string subtitle
    property var actions: []
    property bool open: false

    // The action buttons, in order (for tests and for focus handling)
    readonly property var buttons: _buttons

    signal actionTriggered(int index)

    function show() {
        open = true
    }

    function hide() {
        open = false
    }

    property var _buttons: []

    width: 392
    implicitWidth: 392
    implicitHeight: layout.implicitHeight + 2 * Theme.sp(3.5)

    opacity: open ? 1 : 0
    visible: opacity > 0
    scale: open ? 1 : 0.98

    Behavior on opacity {
        enabled: !Theme.reducedMotion
        NumberAnimation {
            duration: root.open ? Theme.durSlow : Theme.durFast
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
        }
    }
    Behavior on scale {
        enabled: !Theme.reducedMotion
        NumberAnimation {
            duration: root.open ? Theme.durSlow : Theme.durFast
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
        }
    }
    // Translate has no Behavior hook of its own: animate through a plain property
    property real _slide: open ? 0 : 14
    transform: Translate { y: root._slide }
    Behavior on _slide {
        enabled: !Theme.reducedMotion
        NumberAnimation {
            duration: root.open ? Theme.durSlow : Theme.durFast
            easing.type: Theme.easing.type
            easing.bezierCurve: Theme.easing.bezierCurve
        }
    }

    Accessible.role: Accessible.AlertMessage
    Accessible.name: title
    Accessible.description: subtitle

    GlowHalo { // drop shadow, 0 24px 64px -16px
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        radius: Theme.radiusPanel
        spread: 28
        offsetY: 12
        intensity: 0.4
    }

    GlassPanel {
        anchors.fill: parent
        radius: Theme.radiusPanel
        tint: "#221F30"
        tintOpacity: 0.62
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sp(3.5)
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Rectangle { // accent badge with a check mark
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: Theme.accent

                GlowHalo {
                    z: -1
                    anchors.fill: parent
                    color: Theme.accentAlpha(0.5)
                    radius: 18
                    spread: 9
                }
                Icon {
                    anchors.centerIn: parent
                    path: Icons.check
                    color: "#08070D"
                    size: 15
                    strokeWidth: 2.6
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Theme.fontText
                    font.pixelSize: 12
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }

            IconButton {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                iconPath: Icons.close
                iconSize: 10
                iconStrokeWidth: 3.12
                Accessible.name: qsTr("Dismiss notification")
                onClicked: root.hide()
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: root.actions.length > 0
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            uniformCellWidths: true

            Repeater {
                id: repeater
                model: root.actions

                delegate: PillButton {
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 34
                    leftPadding: Theme.sp(3)
                    rightPadding: Theme.sp(3)
                    text: modelData.text ?? ""
                    primary: !!modelData.primary

                    onClicked: {
                        if (typeof modelData.onTriggered === "function")
                            modelData.onTriggered()
                        root.actionTriggered(index)
                    }
                }

                onItemAdded: (index, item) => root._rebuildButtons()
                onItemRemoved: (index, item) => root._rebuildButtons()
            }
        }
    }

    function _rebuildButtons() {
        const list = []
        for (let i = 0; i < repeater.count; ++i) {
            const b = repeater.itemAt(i)
            if (b)
                list.push(b)
        }
        _buttons = list
    }
}
