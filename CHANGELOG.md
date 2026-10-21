# Changelog

All notable changes to Flux Torrent. Flux follows [semantic versioning](https://semver.org); releases are tagged
`v<version>` on GitHub.

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
