import QtQuick
import QtQuick.Layouts
import Flux

// shadcn Sonner-style toast: a popover card at the bottom right of its parent that fades in, stays a
// few seconds and fades out. show(text, isError, actionText) replaces the current one; with an action it
// stays 10 s and shows a button (actionTriggered).
Rectangle {
    id: root

    property string text
    property bool isError: false
    property string actionText: ""
    signal actionTriggered()
    // the toast went away (timeout or action)
    signal dismissed()

    function show(message, error, action) {
        text = message
        isError = error === true
        actionText = action ?? ""
        hideTimer.interval = actionText !== "" ? 10000 : 3500
        opacity = 1
        hideTimer.restart()
    }

    anchors.right: parent ? parent.right : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.margins: Theme.sp(6)
    width: Math.min(360, row.implicitWidth + 32)
    height: Math.max(44, row.implicitHeight + 24)
    radius: Theme.radiusCtl + 2
    color: Theme.popover
    border.width: 1
    border.color: Theme.border
    opacity: 0
    visible: opacity > 0
    z: 100

    Accessible.role: Accessible.AlertMessage
    Accessible.name: text

    Behavior on opacity {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: 180 }
    }

    Timer {
        id: hideTimer
        interval: 3500
        onTriggered: {
            root.opacity = 0
            root.dismissed()
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: Theme.sp(2)

        Icon {
            path: root.isError ? Icons.x : Icons.check
            size: 16
            strokeWidth: 2
            color: root.isError ? Theme.error : Theme.upload
        }
        Text {
            Layout.fillWidth: true
            Layout.maximumWidth: 300
            text: root.text
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        UiButton {
            objectName: "toastAction"
            visible: root.actionText !== ""
            variant: "outline"
            implicitHeight: 28
            text: root.actionText
            onClicked: {
                hideTimer.stop()
                root.opacity = 0
                root.actionTriggered()
            }
        }
    }
}
