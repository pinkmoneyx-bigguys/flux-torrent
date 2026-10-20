import QtQuick
import QtQuick.Controls.Basic
import Flux

// shadcn DropdownMenuSeparator: a 1 px border line with 4 px around it, edge to edge of the menu
MenuSeparator {
    topPadding: 4
    bottomPadding: 4
    leftPadding: -4
    rightPadding: -4

    contentItem: Rectangle {
        implicitWidth: 200
        implicitHeight: 1
        color: Theme.border
    }
}
