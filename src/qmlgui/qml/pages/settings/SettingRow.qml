import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts
import Flux

// One setting inside a SettingsGroup: label and description on the left, the control on the right,
// bound to AppSettings[key] and applied as soon as it changes (text fields on Enter or leaving them).
// type: "switch", "number", "decimal", "text", "password", "path", "select", "textarea".
Item {
    id: row

    property string key
    property string label
    property string description
    property string type: "switch"
    property var options: []        // select: [{key, label}]
    property string suffix          // number: unit shown in the field
    property string placeholder
    property int controlWidth: type === "switch" ? 0
                             : type === "select" ? 220
                             : type === "number" || type === "decimal" ? 150
                             : 340
    // extra control after the main one (e.g. a "Random" button)
    default property alias extra: extraRow.data

    // reading `revision` in the expression itself makes the binding follow every change (a bare
    // `AppSettings.revision;` statement is dropped by the QML compiler and tracks nothing)
    readonly property var value: AppSettings.revision >= 0 ? AppSettings.value(key) : undefined
    property string error: ""

    function commit(v) {
        error = AppSettings.setValue(key, v)
    }

    width: parent ? parent.width : 0
    implicitHeight: Math.max(64, layout.implicitHeight + 28)
    opacity: enabled ? 1 : 0.5

    // divider above every row but the first visible one
    Rectangle {
        visible: row.Positioner.index > 0
        width: parent.width
        height: 1
        color: Theme.border
    }

    GridLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        columns: row.type === "textarea" ? 1 : 2
        columnSpacing: Theme.sp(6)
        rowSpacing: Theme.sp(3)

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: row.label
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.textSm
                font.weight: Font.Medium
                wrapMode: Text.Wrap
            }
            Text {
                visible: row.description !== ""
                Layout.fillWidth: true
                text: row.description
                color: Theme.textDim
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs + 1
                lineHeight: 1.25
                wrapMode: Text.Wrap
            }
            Text {
                visible: row.error !== ""
                Layout.fillWidth: true
                text: row.error
                color: Theme.error
                font.family: Theme.fontText
                font.pixelSize: Theme.textXs + 1
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: row.type === "textarea"
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            spacing: Theme.sp(2)

            UiSwitch {
                objectName: row.type === "switch" ? "setting_" + row.key : ""
                visible: row.type === "switch"
                checked: row.type === "switch" && row.value === true
                Accessible.name: row.label
                onToggled: row.commit(checked)
            }

            UiSelect {
                objectName: row.type === "select" ? "setting_" + row.key : ""
                visible: row.type === "select"
                Layout.preferredWidth: row.controlWidth
                text: row.label
                model: row.options
                currentKey: row.type === "select" ? String(row.value) : ""
                onActivated: key => row.commit(key)
            }

            UiInput {
                id: input
                objectName: ["number", "decimal", "text", "password", "path"].indexOf(row.type) >= 0 ? "setting_" + row.key : ""
                visible: ["number", "decimal", "text", "password", "path"].indexOf(row.type) >= 0
                Layout.preferredWidth: row.controlWidth
                clearable: false
                placeholderText: row.placeholder
                text: row.value === undefined || row.value === null ? ""
                      : row.type === "decimal" ? Number(row.value).toLocaleString(Qt.locale(), "f", 2)
                      : String(row.value)
                field.echoMode: row.type === "password" ? TextInput.Password : TextInput.Normal
                field.horizontalAlignment: row.type === "number" || row.type === "decimal" ? TextInput.AlignRight : TextInput.AlignLeft
                field.rightPadding: row.suffix !== "" ? suffixText.implicitWidth + 10 : 0
                field.validator: row.type === "number" ? intValidator : row.type === "decimal" ? doubleValidator : null
                field.inputMethodHints: row.type === "number" ? Qt.ImhDigitsOnly : Qt.ImhNone
                field.onEditingFinished: row.commitInput()
                Accessible.name: row.label

                Text {
                    id: suffixText
                    visible: row.suffix !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.suffix
                    color: Theme.textDim
                    font.family: Theme.fontText
                    font.pixelSize: Theme.textXs
                }
            }
            UiButton {
                visible: row.type === "path"
                variant: "outline"
                size: "icon"
                iconPath: Icons.folder
                Accessible.name: qsTr("Choose folder")
                onClicked: folderDialog.open()
            }

            RowLayout {
                id: extraRow
                visible: children.length > 0
                spacing: Theme.sp(2)
            }
        }

        // a multi-line list (one item per line)
        Rectangle {
            visible: row.type === "textarea"
            Layout.fillWidth: true
            Layout.columnSpan: 1
            implicitHeight: 120
            radius: Theme.radiusCtl
            color: Theme.inputFill
            border.width: 1
            border.color: area.activeFocus ? Theme.ring : Theme.input

            ScrollView {
                anchors.fill: parent
                anchors.margins: 1
                TextArea {
                    id: area
                    objectName: row.type === "textarea" ? "setting_" + row.key : ""
                    text: row.type === "textarea" ? String(row.value ?? "") : ""
                    placeholderText: row.placeholder
                    placeholderTextColor: Theme.textDim
                    color: Theme.text
                    selectionColor: "#3F3F46"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.textXs + 1
                    wrapMode: TextArea.NoWrap
                    background: null
                    padding: 10
                    onEditingFinished: if (text !== String(row.value ?? "")) row.commit(text)
                    Accessible.name: row.label
                }
            }
        }
    }

    IntValidator { id: intValidator; bottom: -1; top: 2000000 }
    DoubleValidator { id: doubleValidator; bottom: 0; top: 9998; decimals: 2; notation: DoubleValidator.StandardNotation }

    function commitInput() {
        const text = input.text.trim()
        if (row.type === "number") {
            if (text === "" || Number(text) === Number(row.value))
                return
            row.commit(parseInt(text))
        } else if (row.type === "decimal") {
            const n = Number.fromLocaleString(Qt.locale(), text)
            if (isNaN(n) || n === Number(row.value))
                return
            row.commit(n)
        } else if (text !== String(row.value ?? "")) {
            row.commit(row.type === "password" ? input.text : text)
        }
    }

    FolderDialog {
        id: folderDialog
        title: row.label
        currentFolder: row.value ? "file:///" + String(row.value) : ""
        onAccepted: {
            const path = decodeURIComponent(String(selectedFolder).replace(/^file:\/{3}/, ""))
            row.commit(path)
        }
    }
}
