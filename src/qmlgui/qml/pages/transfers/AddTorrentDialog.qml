import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import Flux

// Add torrent: the files as a tree with checkboxes on the left, where and how to add on the right.
// show(source) takes a .torrent file URL or a magnet link; a magnet's file list arrives while the
// dialog is open. With a video inside, it can instead be added to watch without downloading
// (show(source, true) starts there): nothing is kept, the player streams the largest video.
UiDialog {
    id: root
    objectName: "addTorrentDialog"

    property alias draft: draft
    signal torrentAdded(string name)
    signal watchRequested(string torrentId, int fileIndex)

    // "Watch without downloading" picked
    property bool watchMode: false
    // a video is in it (known once the file list is)
    readonly property bool canWatch: draft.hasMetadata && draft.fileCount >= 0 && draft.bestVideoFile() >= 0

    function show(source, watch) {
        error = ""
        watchMode = watch ?? false
        draft.source = ""
        draft.source = source
        open()
    }

    property string error: ""

    preferredWidth: 920
    title: draft.status === "error" ? qsTr("Can't open this torrent") : (draft.name || qsTr("Add torrent"))
    description: {
        if (draft.status === "error")
            return draft.error
        if (draft.status === "metadata")
            return root.watchMode ? qsTr("Fetching the file list from peers… Watching starts as soon as it is here.")
                                  : qsTr("Fetching the file list from peers… You can add it now and choose files later.")
        if (!draft.hasMetadata)
            return qsTr("Magnet link · %1").arg(draft.hash)
        return qsTr("%1 · %n file(s)", "", draft.fileCount).arg(Format.size(draft.totalSize))
    }

    onClosed: draft.cancel()

    AddTorrentDraft {
        id: draft
        objectName: "addTorrentDraft"
        onAdded: name => root.torrentAdded(name)
        onAddedForWatching: (id, file) => root.watchRequested(id, file)
    }

    // Download it, or watch it without keeping anything
    UiTabs {
        objectName: "addModeTabs"
        visible: draft.status !== "error" && (root.canWatch || root.watchMode)
        currentKey: root.watchMode ? "watch" : "download"
        model: [
            { key: "download", label: qsTr("Download") },
            { key: "watch", label: qsTr("Watch without downloading") }
        ]
        onActivated: key => root.watchMode = key === "watch"
    }

    RowLayout {
        Layout.fillWidth: true
        visible: draft.status !== "error"
        spacing: Theme.sp(6)

        // --- Files ------------------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(440, (root.parent ? root.parent.height : 800) - 300)
            radius: Theme.radiusCtl + 2
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 14
                    Layout.rightMargin: 8
                    spacing: Theme.sp(2)

                    UiCheckBox {
                        objectName: "addAllFiles"
                        visible: draft.hasMetadata
                        checked: draft.fileCount > 0 && draft.wantedCount === draft.fileCount
                        partial: draft.wantedCount > 0 && draft.wantedCount < draft.fileCount
                        Accessible.name: qsTr("All files")
                        onClicked: draft.setAllWanted(draft.wantedCount < draft.fileCount)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: draft.hasMetadata
                              ? qsTr("%1 of %2 files · %3").arg(draft.wantedCount).arg(draft.fileCount).arg(Format.size(draft.wantedSize))
                              : qsTr("Files")
                        color: Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

                ListView {
                    id: fileList
                    objectName: "addFileList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: draft.files
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        id: fileRow
                        required property var modelData
                        width: ListView.view.width
                        height: 34
                        color: rowHover.hovered ? Theme.alpha(Theme.muted, 0.5) : Theme.alpha(Theme.muted, 0)
                        Behavior on color {
                            enabled: !Theme.reducedMotion
                            ColorAnimation { duration: Theme.durFast }
                        }
                        HoverHandler { id: rowHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8 + fileRow.modelData.depth * 18
                            anchors.rightMargin: 14
                            spacing: 6

                            // chevron for folders, a spacer for files
                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                Icon {
                                    visible: fileRow.modelData.folder
                                    anchors.centerIn: parent
                                    path: Icons.chevronDown
                                    size: 14
                                    strokeWidth: 2
                                    color: Theme.textDim
                                    rotation: fileRow.modelData.expanded ? 0 : -90
                                }
                                TapHandler {
                                    enabled: fileRow.modelData.folder
                                    onTapped: draft.toggleExpanded(fileRow.modelData.row)
                                }
                            }
                            UiCheckBox {
                                checked: fileRow.modelData.state === 2
                                partial: fileRow.modelData.state === 1
                                Accessible.name: fileRow.modelData.name
                                onClicked: draft.toggle(fileRow.modelData.row)
                            }
                            Icon {
                                path: fileRow.modelData.folder ? Icons.folder : Icons.file
                                size: 15
                                strokeWidth: 1.75
                                color: Theme.textDim
                            }
                            Text {
                                Layout.fillWidth: true
                                text: fileRow.modelData.name
                                color: fileRow.modelData.state === 0 ? Theme.textDim : Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                                font.weight: fileRow.modelData.folder ? Font.Medium : Font.Normal
                                elide: Text.ElideMiddle
                                TapHandler {
                                    onTapped: fileRow.modelData.folder ? draft.toggleExpanded(fileRow.modelData.row)
                                                                       : draft.toggle(fileRow.modelData.row)
                                }
                            }
                            Text {
                                text: Format.size(fileRow.modelData.size)
                                color: Theme.textDim
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textXs + 1
                                font.features: { "tnum": 1 }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: fileList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 48
                        spacing: Theme.sp(3)
                        UiSpinner {
                            visible: draft.status === "metadata"
                            Layout.alignment: Qt.AlignHCenter
                            size: 20
                        }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: draft.status === "metadata" ? qsTr("Asking peers for the file list…")
                                : qsTr("The file list is not known yet. All files will be downloaded; you can change that in the details later.")
                            color: Theme.textDim
                            font.family: Theme.fontText
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }
        }

        // --- Watching: what happens ----------------------------------------------------------
        ColumnLayout {
            objectName: "addWatchInfo"
            visible: root.watchMode
            Layout.fillWidth: false
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: Theme.sp(3)

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 10
                color: Theme.alpha(Theme.download, 0.14)
                Icon {
                    anchors.centerIn: parent
                    path: Icons.play
                    size: 18
                    strokeWidth: 2
                    color: Theme.download
                }
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Watch without downloading")
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textBase
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Only the part you are watching comes down, into a temporary folder. When you close the player the torrent and its files are removed, so nothing takes up space.")
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                wrapMode: Text.Wrap
                lineHeight: 1.15
            }
            Text {
                visible: root.canWatch
                Layout.fillWidth: true
                // files: re-read when the list changes
                text: draft.files.length >= 0 && root.canWatch ? qsTr("Plays: %1").arg(draft.fileName(draft.bestVideoFile())) : ""
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs
                elide: Text.ElideMiddle
            }
        }

        // --- Options ----------------------------------------------------------------------------
        ColumnLayout {
            visible: !root.watchMode
            Layout.fillWidth: false
            Layout.preferredWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: Theme.sp(5)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                FieldLabel { text: qsTr("Save to") }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp(2)
                    UiInput {
                        objectName: "addSavePath"
                        Layout.fillWidth: true
                        clearable: false
                        text: draft.savePath
                        field.onEditingFinished: draft.savePath = text
                    }
                    UiButton {
                        variant: "outline"
                        size: "icon"
                        iconPath: Icons.folder
                        Accessible.name: qsTr("Choose folder")
                        onClicked: folderDialog.open()
                    }
                }
                Text {
                    readonly property bool tight: draft.freeSpace >= 0 && draft.freeSpace < draft.wantedSize
                    visible: draft.freeSpace >= 0
                    Layout.fillWidth: true
                    text: tight ? qsTr("Not enough space: %1 free, %2 needed").arg(Format.size(draft.freeSpace)).arg(Format.size(draft.wantedSize))
                                : qsTr("%1 free on this drive").arg(Format.size(draft.freeSpace))
                    color: tight ? Theme.error : Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                    wrapMode: Text.Wrap
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                FieldLabel { text: qsTr("Category") }
                UiInput {
                    objectName: "addCategory"
                    Layout.fillWidth: true
                    placeholderText: qsTr("None")
                    text: draft.category
                    field.onEditingFinished: draft.category = text
                    onTextChanged: if (text === "") draft.category = ""
                }
                Flow {
                    visible: draft.categories.length > 0
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: draft.categories
                        UiButton {
                            required property string modelData
                            variant: draft.category === modelData ? "secondary" : "outline"
                            implicitHeight: 26
                            text: modelData
                            onClicked: draft.category = draft.category === modelData ? "" : modelData
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp(3)
                OptionSwitch {
                    objectName: "addStartNow"
                    text: qsTr("Start right away")
                    checked: draft.startNow
                    onToggled: on => draft.startNow = on
                }
                OptionSwitch {
                    text: qsTr("Download in order")
                    hint: qsTr("Helps to watch a video while it downloads.")
                    checked: draft.sequential
                    onToggled: on => draft.sequential = on
                }
                OptionSwitch {
                    text: qsTr("First and last pieces first")
                    checked: draft.firstLastPieces
                    onToggled: on => draft.firstLastPieces = on
                }
                OptionSwitch {
                    text: qsTr("Skip hash check")
                    hint: qsTr("Only when the files are already complete on disk.")
                    checked: draft.skipChecking
                    onToggled: on => draft.skipChecking = on
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                FieldLabel { text: qsTr("Content layout") }
                UiSelect {
                    Layout.fillWidth: true
                    text: qsTr("Content layout")
                    currentKey: draft.contentLayout
                    model: [
                        { key: "original", label: qsTr("As in the torrent") },
                        { key: "subfolder", label: qsTr("Always a subfolder") },
                        { key: "noSubfolder", label: qsTr("Never a subfolder") }
                    ]
                    onActivated: key => draft.contentLayout = key
                }
            }
        }
    }

    footerLeftItems: [
        Text {
            visible: root.error !== "" || draft.alreadyAdded
            Layout.maximumWidth: 460
            text: root.error !== "" ? root.error : qsTr("This torrent is already in the list.")
            color: Theme.error
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            elide: Text.ElideRight
        }
    ]
    footerItems: [
        UiButton {
            variant: "outline"
            text: qsTr("Cancel")
            onClicked: root.close()
        },
        UiButton {
            objectName: "addTorrentConfirm"
            visible: !root.watchMode
            iconPath: Icons.plus
            text: qsTr("Add torrent")
            enabled: (draft.status === "ready" || draft.status === "metadata") && !draft.alreadyAdded
                     && (!draft.hasMetadata || draft.wantedCount > 0)
            onClicked: {
                root.error = draft.accept()
                if (root.error === "")
                    root.close()
            }
        },
        UiButton {
            objectName: "addWatchConfirm"
            visible: root.watchMode
            iconPath: draft.hasMetadata ? Icons.play : ""
            text: draft.hasMetadata ? qsTr("Watch") : qsTr("Waiting for the file list…")
            enabled: root.canWatch && !draft.alreadyAdded
            onClicked: {
                root.error = draft.acceptForWatching()
                if (root.error === "")
                    root.close()
            }
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
        property bool checked
        signal toggled(bool on)
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
            objectName: os.objectName !== "" ? os.objectName + "_switch" : ""
            Layout.alignment: Qt.AlignTop
            checked: os.checked
            Accessible.name: os.text
            onToggled: os.toggled(checked)
        }
    }

    FolderDialog {
        id: folderDialog
        title: qsTr("Save to")
        onAccepted: draft.savePath = String(selectedFolder)
    }
}
