import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import Flux

// Search sources: the built-in JacRed (its server can be changed) and the Python plugins; turn them on
// and off, remove plugins, install from a URL or a .py file, install the official set, check for updates.
UiDialog {
    id: root
    objectName: "pluginsDialog"

    preferredWidth: 640
    title: qsTr("Search sources")
    description: SearchEngine.pythonAvailable
                 ? qsTr("Searches use the sources that are on. Plugins are Python scripts: install only the ones you trust.")
                 : qsTr("JacRed works as is. Python plugins need Python 3.9 or newer installed.")

    onOpened: sourceInput.text = ""

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(320, Math.max(120, pluginList.contentHeight + 2))
        radius: Theme.radiusCtl + 2
        color: "transparent"
        border.width: 1
        border.color: Theme.border
        clip: true

        ListView {
            id: pluginList
            objectName: "pluginList"
            anchors.fill: parent
            anchors.margins: 1
            model: SearchEngine.plugins
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: pluginRow
                required property var modelData
                required property int index
                width: pluginList.width
                height: 52

                Rectangle {
                    visible: pluginRow.index < pluginList.count - 1
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: Theme.sp(3)

                    UiSwitch {
                        checked: pluginRow.modelData.enabled
                        Accessible.name: pluginRow.modelData.fullName
                        onToggled: SearchEngine.enablePlugin(pluginRow.modelData.name, checked)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: pluginRow.modelData.fullName
                            color: pluginRow.modelData.enabled ? Theme.text : Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: !(pluginRow.modelData.builtin ?? false)
                            Layout.fillWidth: true
                            text: pluginRow.modelData.url
                            color: Theme.textFaint
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textXs
                            elide: Text.ElideRight
                        }
                        // the built-in source: its server, editable (a mirror)
                        TextInput {
                            objectName: "jacredUrl"
                            visible: pluginRow.modelData.builtin ?? false
                            Layout.fillWidth: true
                            text: pluginRow.modelData.url
                            color: activeFocus ? Theme.text : Theme.textFaint
                            selectionColor: "#3F3F46"
                            selectByMouse: true
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.textXs
                            onEditingFinished: SearchEngine.jacredUrl = text
                        }
                    }
                    UiBadge {
                        visible: pluginRow.modelData.version !== ""
                        text: "v" + pluginRow.modelData.version
                    }
                    UiBadge {
                        visible: pluginRow.modelData.builtin ?? false
                        text: qsTr("Built in")
                    }
                    UiButton {
                        visible: !(pluginRow.modelData.builtin ?? false)
                        size: "iconSm"
                        variant: "ghost"
                        iconPath: Icons.trash
                        Accessible.name: qsTr("Remove %1").arg(pluginRow.modelData.fullName)
                        onClicked: SearchEngine.uninstallPlugin(pluginRow.modelData.name)
                    }
                }
            }
        }

        Text {
            visible: pluginList.count === 0
            anchors.centerIn: parent
            text: qsTr("No plugins installed")
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp(2)
        enabled: SearchEngine.pythonAvailable

        UiInput {
            id: sourceInput
            objectName: "pluginSource"
            Layout.fillWidth: true
            iconPath: Icons.link
            placeholderText: qsTr("Plugin URL (https://…/name.py)")
            onAccepted: installButton.clicked()
        }
        UiButton {
            variant: "outline"
            size: "icon"
            iconPath: Icons.folder
            Accessible.name: qsTr("Choose a plugin file")
            onClicked: fileDialog.open()
        }
        UiButton {
            id: installButton
            variant: "secondary"
            text: qsTr("Install")
            enabled: sourceInput.text.trim() !== "" && !SearchEngine.busy
            onClicked: {
                SearchEngine.installPlugin(sourceInput.text)
                sourceInput.text = ""
            }
        }
    }

    footerLeftItems: [
        UiButton {
            variant: "ghost"
            iconPath: SearchEngine.busy ? "" : Icons.download
            text: qsTr("Official plugins")
            enabled: !SearchEngine.busy && SearchEngine.pythonAvailable
            onClicked: SearchEngine.installOfficialPlugins()
        },
        UiButton {
            variant: "ghost"
            iconPath: Icons.refresh
            text: qsTr("Check for updates")
            enabled: !SearchEngine.busy && SearchEngine.pythonAvailable && SearchEngine.plugins.length > 0
            onClicked: SearchEngine.checkForUpdates()
        },
        UiSpinner {
            visible: SearchEngine.busy
        }
    ]
    footerItems: [
        UiButton {
            text: qsTr("Done")
            onClicked: root.close()
        }
    ]

    FileDialog {
        id: fileDialog
        title: qsTr("Choose a search plugin")
        nameFilters: [qsTr("Search plugins (*.py)")]
        onAccepted: SearchEngine.installPlugin(String(selectedFile))
    }
}
