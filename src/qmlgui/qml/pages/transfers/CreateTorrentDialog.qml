import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import Flux

// Create a torrent: a file or folder to share, trackers, a comment, privacy and piece size; the .torrent
// lands beside the source unless another path is chosen, and the new torrent can seed right away.
// The work runs in TorrentMaker (a worker thread); the dialog shows its progress and can cancel it.
UiDialog {
    id: root
    objectName: "createTorrentDialog"

    property string source
    property string output
    property string error: ""
    // the output path follows the source until edited by hand
    property bool outputEdited: false

    signal createdTorrent(string path, bool seeding)

    title: qsTr("Create a torrent")
    description: qsTr("Share a file or a folder. The .torrent file is saved next to it.")
    preferredWidth: 600

    onSourceChanged: {
        if (!outputEdited)
            output = TorrentMaker.defaultOutput(source)
    }
    onOpened: {
        error = ""
        sourceInput.field.forceActiveFocus()
    }

    Connections {
        target: TorrentMaker
        function onCreated(path, seeding) {
            root.close()
            root.createdTorrent(path, seeding)
        }
        function onFailed(message) {
            root.error = message
        }
    }

    function submit() {
        error = TorrentMaker.create({
            source: source,
            output: output,
            trackers: trackersArea.text,
            webSeeds: "",
            comment: commentInput.text,
            isPrivate: privateSwitch.checked,
            pieceSize: Number(pieceSelect.currentKey),
            format: "hybrid",
            startSeeding: seedSwitch.checked
        })
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.sp(4)
        enabled: !TorrentMaker.busy

        // --- What to share ------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            FieldLabel { text: qsTr("File or folder") }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(2)
                UiInput {
                    id: sourceInput
                    objectName: "createSource"
                    Layout.fillWidth: true
                    clearable: false
                    placeholderText: qsTr("Path to a file or folder")
                    text: root.source
                    field.onEditingFinished: root.source = TorrentMaker.toLocalPath(text)
                }
                UiButton {
                    variant: "outline"
                    iconPath: Icons.file
                    text: qsTr("File…")
                    onClicked: fileDialog.open()
                }
                UiButton {
                    variant: "outline"
                    iconPath: Icons.folder
                    text: qsTr("Folder…")
                    onClicked: folderDialog.open()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            FieldLabel { text: qsTr("Save the .torrent to") }
            UiInput {
                objectName: "createOutput"
                Layout.fillWidth: true
                clearable: false
                text: root.output
                field.onEditingFinished: {
                    root.output = TorrentMaker.toLocalPath(text)
                    root.outputEdited = true
                }
            }
        }

        // --- Trackers -----------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            FieldLabel { text: qsTr("Trackers") }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                radius: Theme.radiusCtl
                color: Theme.inputFill
                border.width: 1
                border.color: trackersArea.activeFocus ? Theme.ring : Theme.input
                Behavior on border.color {
                    enabled: !Theme.reducedMotion
                    ColorAnimation { duration: Theme.durFast }
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    TextArea {
                        id: trackersArea
                        objectName: "createTrackers"
                        padding: 10
                        background: null
                        color: Theme.text
                        placeholderText: qsTr("One per line; an empty line starts a new tier")
                        placeholderTextColor: Theme.textFaint
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        selectionColor: "#3F3F46"
                        wrapMode: TextEdit.NoWrap
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp(4)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                FieldLabel { text: qsTr("Comment") }
                UiInput {
                    id: commentInput
                    Layout.fillWidth: true
                    placeholderText: qsTr("Optional")
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 170
                spacing: 6
                FieldLabel { text: qsTr("Piece size") }
                UiSelect {
                    id: pieceSelect
                    Layout.fillWidth: true
                    text: qsTr("Piece size")
                    currentKey: "0"
                    model: [
                        { key: "0", label: qsTr("Automatic") },
                        { key: "262144", label: "256 KiB" },
                        { key: "524288", label: "512 KiB" },
                        { key: "1048576", label: "1 MiB" },
                        { key: "2097152", label: "2 MiB" },
                        { key: "4194304", label: "4 MiB" },
                        { key: "8388608", label: "8 MiB" },
                        { key: "16777216", label: "16 MiB" }
                    ]
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp(6)
            OptionSwitch {
                id: seedSwitch
                objectName: "createStartSeeding"
                text: qsTr("Start seeding")
                hint: qsTr("Add it to Transfers from where the files are.")
                checked: true
            }
            OptionSwitch {
                id: privateSwitch
                text: qsTr("Private torrent")
                hint: qsTr("Peers only from its trackers: no DHT or peer exchange.")
            }
        }

        // --- Progress -----------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            visible: TorrentMaker.busy
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Hashing the pieces…")
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                }
                Text {
                    text: TorrentMaker.progress + "%"
                    color: Theme.textDim
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textXs
                }
            }
            UiProgress {
                Layout.fillWidth: true
                value: TorrentMaker.progress / 100
                active: true
            }
        }
    }

    footerLeftItems: [
        Text {
            visible: root.error !== ""
            Layout.maximumWidth: 360
            text: root.error
            color: Theme.error
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
    ]
    footerItems: [
        UiButton {
            variant: "outline"
            text: TorrentMaker.busy ? qsTr("Stop") : qsTr("Cancel")
            onClicked: TorrentMaker.busy ? TorrentMaker.cancel() : root.close()
        },
        UiButton {
            objectName: "createTorrentConfirm"
            iconPath: Icons.filePlus
            text: qsTr("Create")
            enabled: !TorrentMaker.busy && root.source !== ""
            onClicked: root.submit()
        }
    ]

    component FieldLabel: Text {
        color: Theme.text
        font.family: Theme.fontText
        font.pixelSize: Theme.textSm
        font.weight: Font.Medium
    }

    component OptionSwitch: RowLayout {
        id: os
        property string text
        property string hint
        property alias checked: sw.checked
        Layout.fillWidth: true
        spacing: Theme.sp(3)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: os.text
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                wrapMode: Text.Wrap
            }
            Text {
                visible: os.hint !== ""
                Layout.fillWidth: true
                text: os.hint
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                wrapMode: Text.Wrap
            }
        }
        UiSwitch {
            id: sw
            objectName: os.objectName !== "" ? os.objectName + "_switch" : ""
            Layout.alignment: Qt.AlignTop
            Accessible.name: os.text
        }
    }

    FileDialog {
        id: fileDialog
        title: qsTr("File to share")
        onAccepted: root.source = TorrentMaker.toLocalPath(String(selectedFile))
    }
    FolderDialog {
        id: folderDialog
        title: qsTr("Folder to share")
        onAccepted: root.source = TorrentMaker.toLocalPath(String(selectedFolder))
    }
}
