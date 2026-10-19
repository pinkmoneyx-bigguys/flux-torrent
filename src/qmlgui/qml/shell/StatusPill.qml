import QtQuick
import QtQuick.Layouts
import Flux

// The status line at the bottom of the window: connection and port, DHT nodes, all-time totals.
// The values bind to SessionFacade; they are plain properties so tests can drive them.
GlassPanel {
    id: root

    property bool connected: SessionFacade.connected
    property int port: SessionFacade.listenPort
    property int dhtNodes: SessionFacade.dhtNodes
    property real totalDownloaded: SessionFacade.totalDownloaded
    property real totalUploaded: SessionFacade.totalUploaded

    implicitHeight: 34
    radius: height / 2

    component StatusText: Text {
        color: Qt.rgba(1, 1, 1, 0.72)
        font.family: Theme.fontMono
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp(4)
        anchors.rightMargin: Theme.sp(4)
        spacing: Theme.sp(5)

        RowLayout {
            spacing: Theme.sp(2)

            Item {
                implicitWidth: 7
                implicitHeight: 7

                GlowHalo {
                    anchors.fill: parent
                    visible: root.connected
                    color: Theme.accent
                    spread: 6
                }
                Rectangle {
                    objectName: "statusDot"
                    anchors.fill: parent
                    radius: width / 2
                    color: root.connected ? Theme.accent : Qt.rgba(1, 1, 1, 0.36)
                }
            }
            StatusText {
                objectName: "statusConnection"
                text: root.connected ? qsTr("Connected · port %1").arg(root.port) : qsTr("No connection")
            }
        }

        StatusText {
            objectName: "statusDht"
            //: %Ln is the number of DHT nodes
            text: qsTr("DHT %Ln nodes", "", root.dhtNodes)
        }

        Item {
            Layout.fillWidth: true
        }

        StatusText {
            objectName: "statusTotals"
            //: All-time amounts downloaded (↓) and uploaded (↑)
            text: qsTr("Total ↓ %1 · ↑ %2").arg(Format.size(root.totalDownloaded)).arg(Format.size(root.totalUploaded))
        }
    }
}
