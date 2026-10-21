pragma Singleton
import QtQuick

// SVG path data of the icon set, all on the 24x24 grid (draw them with controls/Icon.qml).
// Taken verbatim from the approved mockup (App4/Search4/Rss4/Settings4/Main) unless noted.
QtObject {
    // App logo: the wave inside the accent disc of the title bar
    readonly property string logo: "M3 8c4.5 0 4.5 8 9 8s4.5-8 9-8"

    // Navigation
    readonly property string download: "M12 3v12M7 10l5 5 5-5M5 21h14"
    readonly property string search: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4"
    readonly property string rss: "M5 19h.01M5 12a7 7 0 0 1 7 7M5 5a14 14 0 0 1 14 14"
    readonly property string media: "M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM8 4v16M16 4v16"
    readonly property string settings: "M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1M15 4v4M9 10v4M17 16v4"

    // Transfer actions
    readonly property string play: "M7 4.5v15l12-7.5z"
    readonly property string pause: "M9 5v14M15 5v14"
    readonly property string trash: "M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3"
    readonly property string up: "M12 19V5M6 11l6-6 6 6"
    readonly property string down: "M12 5v14M6 13l6 6 6-6"
    // Upload glyph from the first mockup (Main.dc.html): the download glyph mirrored vertically
    readonly property string upload: "M12 21V9M7 14l5-5 5 5M5 3h14"
    readonly property string more: "M5 12h.01M12 12h.01M19 12h.01"
    readonly property string folder: "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
    // "Copy magnet link" menu item
    readonly property string magnet: "M9 4h8a2 2 0 0 1 2 2v8M5 8h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z"
    readonly property string refresh: "M20 12a8 8 0 1 1-2.3-5.7L20 8M20 3v5h-5"

    // Torrent categories
    readonly property string film: "M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1zM8 4v16M16 4v16M4 9h4M4 15h4M16 9h4M16 15h4"
    readonly property string disc: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"
    readonly property string data: "M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3zM4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"
    readonly property string audio: "M9 18V5l12-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z"
    readonly property string app: "M21 8l-9-5-9 5v8l9 5 9-5zM3 8l9 5 9-5M12 13v8"
    // Tray and notifications (lucide bell)
    readonly property string bell: "M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0"

    // Window buttons: the mockup draws them on a 10x10 grid (minimize "M1 5h8", close "M1.5 1.5l7 7M8.5 1.5l-7 7",
    // maximize a rect 1,1,8x8 r2.5); here the same shapes are scaled by 2.4 onto the 24 grid, so at size 10
    // a stroke width of 3.12 gives the mockup's 1.3px line.
    readonly property string minimize: "M2.4 12h19.2"
    readonly property string maximize: "M8.4 2.4h7.2a6 6 0 0 1 6 6v7.2a6 6 0 0 1-6 6H8.4a6 6 0 0 1-6-6V8.4a6 6 0 0 1 6-6z"
    readonly property string close: "M3.6 3.6l16.8 16.8M20.4 3.6L3.6 20.4"

    // Toolbar and controls
    readonly property string turtle: "M3 15c0-4.4 3.6-8 8-8s8 3.6 8 8zM6 15v3M16 15v3M19 13h2.5M8 11l2 2 2-2 2 2"
    readonly property string check: "M5 12.5l4.5 4.5L19 7.5"
    readonly property string list: "M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"
    readonly property string grid: "M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"
    readonly property string info: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 16v-4.5M12 8h.01"
    readonly property string language: "M5 8l6 6M4 14l6-6 2-3M2 5h12M7 2h1M22 22l-5-10-5 10M14 18h6"
    readonly property string alert: "M12 9v4M12 17h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"
    readonly property string hourglass: "M6 3h12M6 21h12M7 3v3a5 5 0 0 0 10 0V3M7 21v-3a5 5 0 0 1 10 0v3"
    readonly property string plus: "M12 5v14M5 12h14"
    readonly property string chevronDown: "M6 9l6 6 6-6"
    readonly property string filter: "M3 5h18M6 12h12M10 19h4"
    // The mockup uses the same sliders glyph for "Columns and density" as for settings
    readonly property string columns: "M4 6h9M17 6h3M4 12h3M11 12h9M4 18h11M19 18h1M15 4v4M9 10v4M17 16v4"

    // Extra glyphs of the mockup used by menus, settings sections and tables
    readonly property string bolt: "M13 3 5 14h6l-1 7 8-11h-6z"
    readonly property string moveTo: "M5 12h14M13 6l6 6-6 6"
    readonly property string speed: "M12 14l4-4M4 18a9 9 0 1 1 16 0"
    readonly property string clock: "M12 7v5l3 2M21 12a9 9 0 1 1-9-9"
    readonly property string externalLink: "M14 4h6v6M20 4l-9 9M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"
    readonly property string sort: "M8 9l4-4 4 4M8 15l4 4 4-4"
    readonly property string network: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"
    readonly property string bittorrent: "M7 7l10 10-5 5V2l5 5L7 17"
    // Transfers screen (lucide-style shapes on the same grid)
    readonly property string link: "M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"
    readonly property string chevronUp: "M6 15l6-6 6 6"
    readonly property string x: "M18 6 6 18M6 6l12 12"
    readonly property string minus: "M5 12h14"
    readonly property string inbox: "M22 12h-6l-2 3h-4l-2-3H2M5.5 5.1 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.5-6.9A2 2 0 0 0 16.8 4H7.2a2 2 0 0 0-1.7 1.1z"
    // Spinner arc (lucide loader-circle), rotated by UiSpinner
    readonly property string loader: "M21 12a9 9 0 1 1-6.2-8.6"
    readonly property string puzzle: "M9 4h3a2 2 0 1 1 4 0h3v5a2 2 0 1 1 0 4v6h-5a2 2 0 1 0-4 0H5v-6a2 2 0 1 0 0-4V4z"
    readonly property string filePlus: "M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5M12 11v6M9 14h6"
    readonly property string file: "M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8zM14 3v5h5"
    readonly property string uiPanel: "M5 4h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM3 9h18M8 9v11"
}
