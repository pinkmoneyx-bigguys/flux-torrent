pragma Singleton
import QtQuick
import Flux

// State of the Transfers screen shared with the sidebar: the status filter it shows
QtObject {
    // "all", "downloading", "seeding", "completed", "stopped", "errored"
    property string status: "all"
    // Set to a torrent id to have the Transfers page select and show it (the command palette)
    property string focusId: ""

    readonly property var filters: [
        { key: "all", label: qsTr("All") },
        { key: "downloading", label: qsTr("Downloading") },
        { key: "seeding", label: qsTr("Seeding") },
        { key: "completed", label: qsTr("Completed") },
        { key: "stopped", label: qsTr("Stopped") },
        { key: "errored", label: qsTr("Errors") }
    ]

    function label(key) {
        for (const f of filters) {
            if (f.key === key)
                return f.label
        }
        return ""
    }
}
