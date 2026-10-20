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
        // just started: reaching its peers again (TorrentListModel::shownState)
        case "connecting": return qsTr("Connecting to peers…")
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
        case "connecting":
        case "metadata":
        case "moving": return Theme.download
        case "seeding":
        case "stalledUp": return Theme.upload
        case "stoppedUp": return Theme.textDim
        case "checking":
        case "stalledDl":
        case "stoppedDl": return Theme.warn
        case "missing":
        case "error": return Theme.error
        default: return Theme.textFaint
        }
    }

    // Status glyph shown before the progress bar
    function icon(state) {
        switch (state) {
        case "downloading":
        case "connecting":
        case "metadata": return Icons.download
        case "stalledDl": return Icons.hourglass
        case "seeding":
        case "stalledUp": return Icons.upload
        case "queuedDl":
        case "queuedUp": return Icons.clock
        case "checking": return Icons.refresh
        case "stoppedDl": return Icons.pause
        case "stoppedUp": return Icons.check
        case "moving": return Icons.moveTo
        default: return Icons.alert
        }
    }

    // Work is under way: the bar shimmers (checking also spins its glyph)
    function isActive(state) {
        return state === "downloading" || state === "connecting" || state === "metadata" || state === "checking"
               || state === "moving"
    }

    function isStopped(state) {
        return state === "stoppedDl" || state === "stoppedUp"
    }
}
