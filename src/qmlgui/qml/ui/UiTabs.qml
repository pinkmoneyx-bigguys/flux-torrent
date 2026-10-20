import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// shadcn Tabs list. `model`: [{key, label, count}] (count optional, shown as a small badge).
// variant "default": a muted track with the active tab raised; "line": text tabs with an underline.
Item {
    id: root

    property var model: []
    property string currentKey
    property string variant: "default"
    signal activated(string key)

    implicitWidth: row.implicitWidth + (variant === "default" ? 6 : 0)
    implicitHeight: variant === "default" ? 34 : 40

    Accessible.role: Accessible.PageTabList

    Rectangle {
        anchors.fill: parent
        visible: root.variant === "default"
        radius: Theme.radiusCtl + 2
        color: Theme.muted
    }

    // The current tab's marker: one item gliding between tabs instead of one per tab
    readonly property Item _currentTab: {
        for (let i = 0; i < tabs.count; ++i) {
            const t = tabs.itemAt(i)
            if (t && t.current)
                return t
        }
        return null
    }
    Item {
        id: marker
        visible: root._currentTab !== null
        x: root._currentTab ? row.x + root._currentTab.x : 0
        y: root._currentTab ? row.y + root._currentTab.y : 0
        width: root._currentTab ? root._currentTab.width : 0
        height: root._currentTab ? root._currentTab.height : 0
        Behavior on x {
            enabled: !Theme.reducedMotion && marker.width > 0
            NumberAnimation { duration: Theme.durMed; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
        }
        Behavior on width {
            enabled: !Theme.reducedMotion && marker.width > 0
            NumberAnimation { duration: Theme.durMed; easing.type: Theme.easing.type; easing.bezierCurve: Theme.easing.bezierCurve }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.variant === "default"
            radius: Theme.radiusCtl
            color: Theme.glass ? Qt.rgba(1, 1, 1, 0.1) : "#0A0A0A"
            border.width: 1
            border.color: Theme.input
        }
        Rectangle {
            visible: root.variant === "line"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.text
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: root.variant === "default" ? 3 : 0
        spacing: root.variant === "default" ? 0 : Theme.sp(4)

        Repeater {
            id: tabs
            model: root.model

            AbstractButton {
                id: tab

                required property var modelData
                readonly property bool current: root.currentKey === modelData.key

                Layout.fillHeight: true
                implicitWidth: tabRow.implicitWidth + (root.variant === "default" ? 2 * 10 : 0)
                focusPolicy: Qt.StrongFocus
                hoverEnabled: true
                text: modelData.label

                Accessible.role: Accessible.PageTab
                Accessible.name: text
                Accessible.selected: current
                Accessible.onPressAction: tab.clicked()

                onClicked: {
                    root.currentKey = modelData.key
                    root.activated(modelData.key)
                }
                Keys.onLeftPressed: nextItemInFocusChain(false).forceActiveFocus()
                Keys.onRightPressed: nextItemInFocusChain(true).forceActiveFocus()

                background: Item {
                    Rectangle {
                        visible: tab.visualFocus
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: Theme.radiusCtl + 2
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.alpha(Theme.ring, 0.6)
                    }
                }
                contentItem: Item {
                    RowLayout {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: tab.text
                            color: tab.current || tab.hovered ? Theme.text : Theme.textDim
                            Behavior on color {
                                enabled: !Theme.reducedMotion
                                ColorAnimation { duration: Theme.durFast }
                            }
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            visible: tab.modelData.count !== undefined && tab.modelData.count > 0
                            implicitWidth: Math.max(20, countText.implicitWidth + 10)
                            implicitHeight: 20
                            radius: 10
                            color: tab.current ? Theme.alpha(Theme.text, 0.12) : Theme.alpha(Theme.textDim, 0.18)
                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: tab.modelData.count ?? ""
                                color: tab.current ? Theme.text : Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
