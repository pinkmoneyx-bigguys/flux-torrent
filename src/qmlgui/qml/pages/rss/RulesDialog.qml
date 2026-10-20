import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Flux

// Auto-download rules: the list on the left, the selected rule's form on the right with a live preview
// of the known articles it would download. Saving writes the rule through RssManager.
UiDialog {
    id: root
    objectName: "rssRulesDialog"

    preferredWidth: 920
    title: qsTr("Auto-download rules")
    description: qsTr("New articles of the chosen feeds that match a rule are downloaded automatically.")

    // The rule being edited (a copy) and the name it was loaded with ("" for a new rule)
    property var draft: null
    property string originalName: ""
    property string error: ""
    property var preview: []

    function blank() {
        return { name: "", enabled: true, mustContain: "", mustNotContain: "", useRegex: false, smartFilter: false,
                 episodeFilter: "", ignoreDays: 0, feeds: [], category: "", savePath: "" }
    }
    function edit(rule) {
        draft = Object.assign(blank(), rule ?? {})
        originalName = rule ? rule.name : ""
        error = ""
        updatePreview()
    }
    function set(key, value) {
        const d = Object.assign({}, draft)
        d[key] = value
        draft = d
        previewTimer.restart()
    }
    function toggleFeed(url, on) {
        const feeds = draft.feeds.filter(f => f !== url)
        if (on)
            feeds.push(url)
        set("feeds", feeds)
    }
    function updatePreview() {
        preview = draft ? RssManager.previewRule(draft) : []
    }
    function save() {
        error = RssManager.saveRule(draft, originalName)
        if (error === "")
            originalName = draft.name.trim()
    }

    onOpened: edit(RssManager.rules.length > 0 ? RssManager.rules[0] : null)

    Timer {
        id: previewTimer
        interval: 250
        onTriggered: root.updatePreview()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp(3)
        UiSwitch {
            id: autoSwitch
            objectName: "rssAutoDownloadSwitch"
            checked: RssManager.autoDownloadEnabled
            Accessible.name: autoLabel.text
            onToggled: RssManager.autoDownloadEnabled = checked
        }
        Text {
            id: autoLabel
            Layout.fillWidth: true
            text: RssManager.autoDownloadEnabled ? qsTr("Auto-download is on") : qsTr("Auto-download is off: rules are kept but do not run")
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            TapHandler { onTapped: autoSwitch.toggle() }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(560, (root.parent ? root.parent.height : 800) - 260)
        radius: Theme.radiusCtl + 2
        color: "transparent"
        border.width: 1
        border.color: Theme.border
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // Rules list --------------------------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: false // nested layouts fill by default
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                spacing: 0

                ListView {
                    id: ruleList
                    objectName: "rssRuleList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    topMargin: 6
                    model: RssManager.rules
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: AbstractButton {
                        id: ruleRow
                        required property var modelData
                        readonly property bool current: root.originalName === modelData.name
                        width: ListView.view.width
                        height: 34
                        leftPadding: 16
                        rightPadding: 12
                        hoverEnabled: true
                        text: modelData.name
                        Accessible.role: Accessible.ListItem
                        Accessible.name: text
                        Accessible.selected: current
                        onClicked: root.edit(modelData)
                        background: Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            radius: Theme.radiusCtl - 2
                            color: ruleRow.current ? Theme.selected : ruleRow.hovered ? Theme.hover : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: Theme.sp(2)
                            Rectangle {
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: ruleRow.modelData.enabled ? Theme.upload : Theme.textFaint
                            }
                            Text {
                                Layout.fillWidth: true
                                text: ruleRow.text
                                color: Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                                font.weight: ruleRow.current ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        visible: ruleList.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 32
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: qsTr("No rules yet")
                        color: Theme.textDim
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }
                UiButton {
                    objectName: "rssNewRule"
                    Layout.fillWidth: true
                    Layout.margins: 8
                    variant: "ghost"
                    iconPath: Icons.plus
                    text: qsTr("New rule")
                    onClicked: root.edit(null)
                }
            }

            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.border }

            // Form --------------------------------------------------------------------------------
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: form.implicitHeight + 40
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                visible: root.draft !== null

                ColumnLayout {
                    id: form
                    x: 20
                    y: 20
                    width: parent.width - 40
                    spacing: Theme.sp(4)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(3)
                        Field {
                            Layout.fillWidth: true
                            label: qsTr("Name")
                            UiInput {
                                objectName: "rssRuleName"
                                Layout.fillWidth: true
                                placeholderText: qsTr("e.g. My show 1080p")
                                text: root.draft ? root.draft.name : ""
                                onTextChanged: if (root.draft && text !== root.draft.name) root.set("name", text)
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: false
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                            spacing: Theme.sp(2)
                            UiSwitch {
                                id: enabledSwitch
                                checked: root.draft ? root.draft.enabled : false
                                Accessible.name: qsTr("Rule is on")
                                onToggled: root.set("enabled", checked)
                            }
                            Text {
                                text: qsTr("On")
                                color: Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: Theme.textSm
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(3)
                        Field {
                            Layout.fillWidth: true
                            label: qsTr("Must contain")
                            hint: root.draft && root.draft.useRegex ? qsTr("A regular expression.")
                                                                     : qsTr("Words are all required; | means or; * matches anything.")
                            UiInput {
                                objectName: "rssRuleMustContain"
                                Layout.fillWidth: true
                                text: root.draft ? root.draft.mustContain : ""
                                onTextChanged: if (root.draft && text !== root.draft.mustContain) root.set("mustContain", text)
                            }
                        }
                        Field {
                            Layout.fillWidth: true
                            label: qsTr("Must not contain")
                            hint: qsTr("Skips matching articles, e.g. 720p | CAM")
                            UiInput {
                                Layout.fillWidth: true
                                text: root.draft ? root.draft.mustNotContain : ""
                                onTextChanged: if (root.draft && text !== root.draft.mustNotContain) root.set("mustNotContain", text)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(6)
                        SwitchRow {
                            text: qsTr("Regular expressions")
                            checked: root.draft ? root.draft.useRegex : false
                            onToggled: on => root.set("useRegex", on)
                        }
                        SwitchRow {
                            text: qsTr("Smart episode filter")
                            checked: root.draft ? root.draft.smartFilter : false
                            onToggled: on => root.set("smartFilter", on)
                        }
                    }

                    Field {
                        Layout.fillWidth: true
                        label: qsTr("Episodes")
                        hint: qsTr("Optional, e.g. 1x2;8-15;5;30- (season 1: episode 2, 8 to 15, 5, 30 and later)")
                        UiInput {
                            Layout.fillWidth: true
                            text: root.draft ? root.draft.episodeFilter : ""
                            onTextChanged: if (root.draft && text !== root.draft.episodeFilter) root.set("episodeFilter", text)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp(3)
                        Field {
                            Layout.fillWidth: false
                            Layout.preferredWidth: 200
                            label: qsTr("Category")
                            UiInput {
                                Layout.fillWidth: true
                                text: root.draft ? root.draft.category : ""
                                onTextChanged: if (root.draft && text !== root.draft.category) root.set("category", text)
                            }
                        }
                        Field {
                            Layout.fillWidth: true
                            label: qsTr("Save to")
                            UiInput {
                                Layout.fillWidth: true
                                placeholderText: qsTr("Default save path")
                                text: root.draft ? root.draft.savePath : ""
                                onTextChanged: if (root.draft && text !== root.draft.savePath) root.set("savePath", text)
                            }
                        }
                    }

                    Field {
                        Layout.fillWidth: true
                        label: qsTr("Apply to feeds")
                        Flow {
                            Layout.fillWidth: true
                            spacing: Theme.sp(2)
                            Repeater {
                                model: RssManager.feeds.filter(f => !f.folder)
                                RowLayout {
                                    required property var modelData
                                    spacing: Theme.sp(2)
                                    UiCheckBox {
                                        checked: root.draft ? root.draft.feeds.indexOf(modelData.url) >= 0 : false
                                        Accessible.name: modelData.name
                                        onClicked: root.toggleFeed(modelData.url, checked)
                                    }
                                    Text {
                                        Layout.rightMargin: Theme.sp(3)
                                        text: modelData.name
                                        color: Theme.text
                                        font.family: Theme.fontText
                                        font.pixelSize: Theme.textSm
                                    }
                                }
                            }
                        }
                    }

                    Field {
                        Layout.fillWidth: true
                        label: qsTr("Would download now (%1)").arg(root.preview.length)
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.max(44, previewColumn.implicitHeight + 16)
                            radius: Theme.radiusCtl
                            color: Theme.alpha(Theme.muted, 0.5)
                            Column {
                                id: previewColumn
                                x: 12
                                y: 8
                                width: parent.width - 24
                                spacing: 4
                                Repeater {
                                    model: root.preview.slice(0, 8)
                                    Text {
                                        required property var modelData
                                        width: previewColumn.width
                                        text: modelData
                                        color: Theme.text
                                        font.family: Theme.fontText
                                        font.pixelSize: Theme.textXs + 1
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    visible: root.preview.length === 0 || root.preview.length > 8
                                    width: previewColumn.width
                                    text: root.preview.length === 0
                                          ? (root.draft && root.draft.feeds.length === 0 ? qsTr("Pick at least one feed.")
                                                                                         : qsTr("No current article matches."))
                                          : qsTr("and %1 more").arg(root.preview.length - 8)
                                    color: Theme.textDim
                                    font.family: Theme.fontText
                                    font.pixelSize: Theme.textXs + 1
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.error !== ""
                        Layout.fillWidth: true
                        text: root.error
                        color: Theme.error
                        font.family: Theme.fontText
                        font.pixelSize: Theme.textSm
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    footerLeftItems: [
        UiButton {
            visible: root.originalName !== ""
            variant: "ghost"
            iconPath: Icons.trash
            text: qsTr("Delete rule")
            onClicked: {
                RssManager.removeRule(root.originalName)
                root.edit(RssManager.rules.length > 0 ? RssManager.rules[0] : null)
            }
        }
    ]
    footerItems: [
        UiButton { variant: "outline"; text: qsTr("Close"); onClicked: root.close() },
        UiButton {
            objectName: "rssSaveRule"
            text: root.originalName === "" ? qsTr("Create rule") : qsTr("Save")
            enabled: root.draft !== null && root.draft.name.trim() !== ""
            onClicked: root.save()
        }
    ]

    // --- Pieces ---------------------------------------------------------------------------------
    component Field: ColumnLayout {
        property string label
        property string hint
        default property alias content: box.data
        spacing: 6
        Text {
            text: parent.label
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
            font.weight: Font.Medium
        }
        ColumnLayout {
            id: box
            Layout.fillWidth: true
            spacing: 0
        }
        Text {
            visible: parent.hint !== ""
            Layout.fillWidth: true
            text: parent.hint
            color: Theme.textDim
            font.family: Theme.fontText
            font.pixelSize: Theme.textXs
            wrapMode: Text.Wrap
        }
    }

    component SwitchRow: RowLayout {
        id: sr
        property string text
        property bool checked
        signal toggled(bool on)
        Layout.fillWidth: false
        spacing: Theme.sp(2)
        UiSwitch {
            checked: sr.checked
            Accessible.name: sr.text
            onToggled: sr.toggled(checked)
        }
        Text {
            text: sr.text
            color: Theme.text
            font.family: Theme.fontText
            font.pixelSize: Theme.textSm
        }
    }
}
