pragma Singleton
import QtQuick
import Flux

// Labels and colours of TorrentListModel state keys, shared by the list and the details pane
QtObject {
    function label(state) {
        switch (state) {
        case "downloading": return qsTr("Downloading")
        case "metadata": return qsTr("Fetching metadata")
        case "stalledDl": return qsTr("Stalled")
        case "seeding":
        case "stalledUp": return qsTr("Seeding")
        case "queuedDl":
        case "queuedUp": return qsTr("Queued")
        case "checking": return qsTr("Checking")
        case "stoppedDl": return qsTr("Stopped")
        case "stoppedUp": return qsTr("Completed")
        case "moving": return qsTr("Moving")
        case "missing": return qsTr("Missing files")
        default: return qsTr("Error")
        }
    }

    // Status dot and progress bar colour
    function color(state) {
        switch (state) {
        case "downloading":
        case "metadata":
        case "moving": return Theme.download
        case "seeding":
        case "stalledUp":
        case "stoppedUp": return Theme.upload
        case "checking":
        case "stalledDl": return Theme.warn
        case "missing":
        case "error": return Theme.error
        default: return Theme.textFaint
        }
    }

    function isStopped(state) {
        return state === "stoppedDl" || state === "stoppedUp"
    }
}
