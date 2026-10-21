# Changelog

All notable changes to Flux Torrent. Flux follows [semantic versioning](https://semver.org); releases are tagged
`v<version>` on GitHub.

## [0.1.2]

### New

- **A film's card in the tracker search says what each release is.** The whole name of every release (the
  voice-overs are in it), with chips for its quality, HDR or Dolby Vision, source, codec, season, episodes, the kind
  of voice-over and the studios. Narrow the releases down by quality, voice-over or words, and sort them by seeds,
  date or size. Above them: what the film is about, from Wikipedia in your language, and a trailer search.
- **Search finds what you asked for.** Only the films whose titles have your words stay: a tracker also finds them in
  genres and notes ("киберпанк" brought Serial Experiments Lain). A bar above the results shows the rest on a click.
- **Cards first.** The search opens as a grid of posters, and releases of one film join up more often.
- **The media library is a shelf of posters**: one per film or series. A film plays from its poster; a series
  opens its episodes by season, with what was watched and what is still downloading.
- **RSS reads better**: the articles are rows with the torrent a click away, the reader has room, and the panes fill
  the page.

### Better

- Scrolling with the mouse wheel glides, and the grids stay smooth with many posters.
- Posters are kept on disk and come more reliably; the cards on screen get theirs first.

## [0.1.1]

### New

- **Flux in the notification area.** An icon by the clock shows the download and upload speeds; a click opens or
  hides the window, and its menu — in Flux's own look — adds a torrent file or a magnet link, starts or stops all
  torrents, switches the alternative speed limits and exits Flux.
- **Closing the window keeps Flux running**, as qBittorrent does: downloads and seeding go on in the background.
  Optionally, minimizing sends the window there too. *Settings → Tray & notifications* turns each of these off.
- **A notification when a download finishes**, unless Flux is the window in front.

### Fixed

- An update left the downloaded installer in the temporary folder until the next start of Flux.
- Switches and checkboxes changed by a screen reader now save the setting, as a click does.

## [0.1.0] — first public release

Flux Torrent is a new Windows interface for the qBittorrent 5.2.4 engine (libtorrent 2.0.11), with streaming and a
built-in player on top.

### Highlights

- **Watch while it downloads.** A built-in player (mpv) plays a video while the torrent is still downloading:
  Flux asks for the pieces right ahead of the playhead first. *Watch without downloading* keeps a film in a
  temporary cache and clears it afterwards.
- **Tracker search with posters.** A built-in movie & TV source (JacRed) next to qBittorrent's search plugins;
  results grouped into film cards with posters from IMDb, Wikipedia and Shikimori.
- **Transfers.** Two-line rows, a live per-torrent speed graph, rolling speed figures, resizable columns and a
  details pane with pieces, files, trackers and peers.
- **Media library** of every video in your torrents, **RSS** with auto-download rules, a **command palette**
  (<kbd>Ctrl</kbd>+<kbd>K</kbd>).
- **Nine languages:** English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski,
  简体中文 — switched on the fly.
- **Moving from qBittorrent:** on the first start Flux copies your torrents and settings over in one click.
- **Updates itself** from GitHub releases, checking the download's SHA-256 before it installs.
- **An installer of its own**, in Flux's look: per-user (no administrator rights), Start menu and desktop
  shortcuts, `.torrent` files and magnet links, an entry in *Installed apps* to remove it. A **portable** build
  is available too.
