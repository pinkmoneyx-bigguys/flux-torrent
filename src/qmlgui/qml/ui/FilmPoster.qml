import QtQuick
import QtQuick.Layouts
import Flux

// A film poster from Posters. Until (or unless) one is found: a tinted cover with the Flux mark in the
// middle and, when there is room, the film's title and year under it.
// `film`: {key, title, original, year, series}, as Posters.film() gives (the look-up starts when it is set).
// Used by the tracker search and the media library.
Rectangle {
    id: poster
    property var film: ({})
    // the picture kept on disk (Posters fetches it the first time)
    readonly property string url: Posters.revision >= 0 && film.key ? Posters.image(film.key) : ""
    readonly property real hue: {
        let h = 0
        const t = film.title || ""
        for (let i = 0; i < t.length; ++i)
            h = (h * 31 + t.charCodeAt(i)) % 360
        return h / 360
    }

    radius: 6
    clip: true
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.hsla(poster.hue, 0.25, 0.20, 1) }
        GradientStop { position: 1; color: Qt.hsla((poster.hue + 0.06) % 1, 0.28, 0.10, 1) }
    }
    Component.onCompleted: {
        if (film.key)
            Posters.request(film.key, film.title, film.original, film.year, film.series)
    }
    onFilmChanged: {
        if (film.key)
            Posters.request(film.key, film.title, film.original, film.year, film.series)
    }

    ColumnLayout {
        objectName: "posterPlaceholder"
        anchors.centerIn: parent
        width: parent.width - 2 * Math.max(4, parent.width * 0.1)
        visible: image.status !== Image.Ready
        spacing: Math.max(4, poster.width * 0.05)

        // the Flux mark on a soft tile
        Rectangle {
            readonly property real side: poster.width < 60 ? Math.min(poster.width * 0.62, 22) : Math.min(48, poster.width * 0.26)
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: side
            implicitHeight: side
            radius: side * 0.25
            color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Icon {
                anchors.centerIn: parent
                path: Icons.logo
                size: parent.side * 0.62
                strokeWidth: 2.4
                color: Qt.rgba(1, 1, 1, 0.82)
            }
        }
        Text {
            visible: poster.width >= 100
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: poster.film.title || ""
            color: Qt.rgba(1, 1, 1, 0.88)
            font.family: Theme.fontText
            font.pixelSize: Math.round(Math.min(15, Math.max(12, poster.width * 0.075)))
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Text {
            visible: poster.width >= 100
            Layout.fillWidth: true
            text: [poster.film.original && poster.film.original !== poster.film.title ? poster.film.original : "",
                   poster.film.year > 0 ? String(poster.film.year) : ""].filter(t => t !== "").join(" · ")
            color: Qt.rgba(1, 1, 1, 0.55)
            font.family: Theme.fontText
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }
    // the picture itself, drawn by the shader below: cropped to fill and with the rounded corners
    Image {
        id: image
        visible: false
        source: poster.url
        asynchronous: true
        // decoded at the size it is shown at (twice, for sharp corners on high DPI screens)
        sourceSize.width: Math.ceil(poster.width * 2)
    }
    ShaderEffect {
        anchors.fill: parent
        visible: image.status === Image.Ready
        opacity: visible ? 1 : 0
        Behavior on opacity {
            enabled: !Theme.reducedMotion
            NumberAnimation { duration: Theme.durMed }
        }
        property variant source: image
        property size size: Qt.size(width, height)
        property real radius: poster.radius
        // the part of the picture that fills the card, per axis
        readonly property real pictureAspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 1
        readonly property real cardAspect: height > 0 ? width / height : 1
        property size crop: pictureAspect > cardAspect ? Qt.size(cardAspect / pictureAspect, 1)
                                                       : Qt.size(1, pictureAspect / cardAspect)
        fragmentShader: "qrc:/flux/shaders/poster.frag.qsb"
    }
    // the outline over the picture
    Rectangle {
        anchors.fill: parent
        radius: poster.radius
        color: "transparent"
        border.width: poster.border.width
        border.color: poster.border.color
    }
}
