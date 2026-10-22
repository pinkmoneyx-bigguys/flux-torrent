<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <b>English</b> ·
  <a href="docs/i18n/README.ru.md">Русский</a> ·
  <a href="docs/i18n/README.uk.md">Українська</a> ·
  <a href="docs/i18n/README.de.md">Deutsch</a> ·
  <a href="docs/i18n/README.es.md">Español</a> ·
  <a href="docs/i18n/README.fr.md">Français</a> ·
  <a href="docs/i18n/README.pt-BR.md">Português</a> ·
  <a href="docs/i18n/README.pl.md">Polski</a> ·
  <a href="docs/i18n/README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="docs/assets/logo.svg" width="96" height="96" alt="Flux Torrent logo">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>A torrent client you’ll actually enjoy looking at.</b><br>
  The rock-solid core of qBittorrent, a brand-new interface, and a player that starts the movie while it downloads.
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><img src="https://img.shields.io/github/v/release/pinkmoneyx-bigguys/flux-torrent?style=flat-square&color=4f8cff&label=release" alt="Latest release"></a>
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases"><img src="https://img.shields.io/github/downloads/pinkmoneyx-bigguys/flux-torrent/total?style=flat-square&color=22c55e&label=downloads" alt="Downloads"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0a0a0a?style=flat-square" alt="Windows 10 and 11">
  <img src="https://img.shields.io/badge/core-qBittorrent%205.2.4-2f67ba?style=flat-square&logo=qbittorrent&logoColor=white" alt="qBittorrent 5.2.4 core">
  <img src="https://img.shields.io/badge/UI-Qt%206.10%20%2B%20QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="Qt 6.10">
  <img src="https://img.shields.io/badge/languages-9-ff7a59?style=flat-square" alt="9 languages">
  <a href="COPYING"><img src="https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square" alt="License: GPL-2.0-or-later"></a>
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Download for Windows</b></a>
  &nbsp;·&nbsp;
  <a href="https://pinkmoneyx-bigguys.github.io/flux-torrent/"><b>Website</b></a>
  &nbsp;·&nbsp;
  <a href="#-features">Features</a>
  &nbsp;·&nbsp;
  <a href="#-screenshots">Screenshots</a>
  &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#-build-from-source">Build</a>
</p>

<p align="center">
  <img src="docs/assets/hero.png" alt="Flux Torrent: the Transfers screen with a live speed graph" width="100%">
</p>

---

## 💡 Why Flux

qBittorrent is the most dependable open-source torrent engine there is — and it still looks like 2010.
Flux keeps that engine **untouched** (qBittorrent 5.2.4 on libtorrent 2.0) and builds a modern Windows app around it:

- 🎬 **Watch first, download later.** Press play on a torrent and the movie starts in seconds — Flux fetches the pieces you are about to see before the rest.
- 🔎 **Search that understands films.** Results are grouped by movie, with posters, years and every release in one card.
- ✨ **A calm, fast interface.** Dark, clean and fluid, with live graphs and figures that roll instead of blink.
- 🧳 **Nothing to lose.** Your qBittorrent torrents and settings move over in one click on the first start.

## ✨ Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Built-in player & streaming</h3>
      Play a video while the torrent is still downloading. Flux asks for the pieces right ahead of the playhead first, shows an honest buffer gauge, and remembers where you stopped.
      <br><br>
      <b>Watch without downloading</b> keeps a film in a temporary cache and clears it when you are done — nothing piles up on your disk.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Tracker search with posters</h3>
      A built-in movie & TV source (JacRed) works out of the box — no Python needed — next to the classic qBittorrent search plugins.
      <br><br>
      Results become <b>film cards</b>: posters found on IMDb, Wikipedia and Shikimori, every release of a film in one place, “With seeds” and “With posters” switches, a list or a grid.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Transfers that tell you what is going on</h3>
      Two-line rows with clear statuses, a live per-torrent speed graph, rolling speed figures, resizable columns, and a details pane with pieces, files, trackers and peers.
      <br><br>
      A torrent you just started says <i>“Connecting to peers…”</i> instead of looking stuck.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Media library</h3>
      Every video in your torrents, sorted into movies and series with seasons and episodes, quality badges and progress — ready to play from one screen.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS with auto-download</h3>
      Feeds and folders, a clean article reader, and rules that grab new episodes for you as soon as they appear.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Made for the keyboard</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> opens a command palette for everything: add a torrent, jump to a page, toggle speed limits, check for updates…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Updates itself</h3>
      Flux checks GitHub releases when it starts. One click on <b>Update and restart</b> downloads the new version, verifies its SHA-256 checksum, puts it in place and opens it again.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Speaks your language</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski and 简体中文. Switching takes a second — no restart — and numbers and dates follow the language.
    </td>
  </tr>
</table>

And everything you expect from qBittorrent is still there: sequential and first/last-piece downloads, categories, speed limits with a schedule, the queue, DHT / PeX / LSD, encryption, proxies, UPnP / NAT-PMP, torrent creation and the full set of advanced libtorrent settings.

## 📸 Screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/assets/search.png" alt="Tracker search"><p align="center"><sub>Tracker search</sub></p></td>
    <td width="50%"><img src="docs/assets/library.png" alt="Media library"><p align="center"><sub>Media library</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="docs/assets/rss.png" alt="RSS feeds"><p align="center"><sub>RSS feeds and the article reader</sub></p></td>
    <td width="50%"><img src="docs/assets/languages.png" alt="Language settings"><p align="center"><sub>Nine languages, switched on the fly</sub></p></td>
  </tr>
</table>

## 🚀 Getting started

Grab one of the two from the [latest release](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest):

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** — *recommended* | The installer, in Flux’s own look. Installs for you alone, so no administrator rights are needed; adds Start menu and desktop shortcuts, opens `.torrent` files and magnet links, and appears in *Installed apps* to remove it. New versions update in place. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | The portable build. Unpack anywhere — a USB stick works — and run `Flux.exe`. Settings and torrents stay in its `profile` folder, and it updates itself too. |

On the first start Flux offers to **move your torrents and settings from qBittorrent**. Close qBittorrent first, then press *Migrate*. Prefer a clean slate? Choose *Start fresh*.

**Requirements:** Windows 10 (1809 or newer) or Windows 11, 64-bit. Nothing else to install: Flux brings everything it needs.

## ⌨️ Keyboard shortcuts

| Shortcut | Action | | In the player | Action |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Command palette | | <kbd>Space</kbd> | Play / pause |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Add a torrent file | | <kbd>←</kbd> <kbd>→</kbd> | Seek back / forward |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Transfers, Search, RSS, Library | | <kbd>↑</kbd> <kbd>↓</kbd> | Volume |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Settings | | <kbd>M</kbd> | Mute |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Fold the sidebar | | <kbd>F</kbd> | Full screen |
| | | | <kbd>Esc</kbd> | Leave the player |

## ❓ FAQ

<details>
<summary><b>Is Flux a fork of qBittorrent?</b></summary>
<br>
Yes. The engine — sessions, resume data, trackers, the BitTorrent protocol itself — is qBittorrent 5.2.4 on libtorrent 2.0.11. Flux replaces the interface with a new one written in Qt Quick (QML) and adds streaming, the player, the media library, the movie search and the updater on top.
</details>

<details>
<summary><b>Will it mess up my qBittorrent?</b></summary>
<br>
No. Flux keeps its own profile (<code>%APPDATA%\Flux</code> and <code>%LOCALAPPDATA%\Flux</code>). Migration <i>copies</i> your qBittorrent torrents and settings; the original profile stays as it was. Just don’t run the same torrents in both apps at once.
</details>

<details>
<summary><b>Why does a torrent take a few seconds to speed up after “Start”?</b></summary>
<br>
Stopping a torrent closes its connections. On start, Flux reaches the peers again, and it is up to them when to start sending — most clients reconsider that every 10–15 seconds. Flux shows <i>“Connecting to peers…”</i> meanwhile. qBittorrent behaves exactly the same.
</details>

<details>
<summary><b>Windows says the installer is “unrecognized”. Is it safe?</b></summary>
<br>
SmartScreen warns about every new program that has no paid code-signing certificate yet, and Flux doesn’t have one. Click <i>More info</i> → <i>Run anyway</i>. To be sure the file is the one published here, compare its SHA-256 with <code>SHA256SUMS.txt</code> in the release (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> in PowerShell).
</details>

<details>
<summary><b>How do I remove Flux?</b></summary>
<br>
Open <i>Settings → Apps → Installed apps</i>, find <b>Flux Torrent</b> and choose <i>Uninstall</i>. The uninstaller asks whether to keep your settings and the list of torrents; downloaded files are never touched. The portable build is just a folder: delete it.
</details>

<details>
<summary><b>Do I need Python for search?</b></summary>
<br>
Not for the built-in movie & TV source. Python is only needed for the classic qBittorrent search plugins, the same as in qBittorrent.
</details>

<details>
<summary><b>Is there a Web UI, a Linux or a macOS version?</b></summary>
<br>
Flux is Windows-only for now. The qBittorrent Web UI is still built in (disabled by default; it can be turned on in the configuration file).
</details>

<details>
<summary><b>Is it legal?</b></summary>
<br>
BitTorrent is a technology for sharing files, used every day for Linux distributions, games, open movies and backups. Flux is a client, like any other. What you download and share is your own responsibility — please respect the laws of your country.
</details>

## 🛠 Build from source

<details>
<summary><b>Show the steps</b></summary>
<br>

Everything is scripted in PowerShell. The first script installs the toolchain (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg with OpenSSL, zlib, Boost 1.90 and libtorrent 2.0.11, libmpv) and pins the versions in <a href="scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Toolchain and dependencies (run once, in an elevated PowerShell)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Build the QML interface and run the tests
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Put a runnable copy, with its Qt and DLLs, in deploy\
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. A release in dist\: the installer, the portable zip, checksums and release notes
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Publish the files from <code>dist\</code> in a GitHub release tagged <code>v&lt;version&gt;</code> (see <a href="CHANGELOG.md"><code>CHANGELOG.md</code></a>) — every Flux out there then offers the update: an installed one takes the installer, a portable one the zip.

**Project layout**

| Path | What lives there |
|---|---|
| `src/base`, `src/app` | qBittorrent’s engine and application, kept close to upstream |
| `src/qmlgui/qml` | The interface: pages, controls, the player |
| `src/qmlgui/backend` | C++ models the interface talks to (torrents, search, posters, RSS, updates, languages…) |
| `src/qmlgui/streaming` | Streaming: read-ahead planning and the local stream server |
| `src/qmlgui/i18n` | Translations (`flux_<code>.ts`) |
| `src/installer` | The installer: a dependency-free self-extracting stub and its QML interface |
| `test/qmlgui` | C++ and QML tests |

</details>

## 🌍 Translations

Flux is translated into 9 languages. The strings live in [`src/qmlgui/i18n`](src/qmlgui/i18n) as Qt `.ts` files, one per language, and open in Qt Linguist or any text editor.

Spotted an awkward phrase, or want your language added? [Open an issue](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) or send a pull request — [`CONTRIBUTING.md`](CONTRIBUTING.md) shows where everything lives, and a check on every pull request makes sure each translation is complete and keeps its placeholders.

## 🤝 Contributing

Bug reports, ideas and pull requests are welcome — [`CONTRIBUTING.md`](CONTRIBUTING.md) has the details. Before you open a pull request, please run the tests:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Credits

Flux stands on the shoulders of great open-source projects:

- [qBittorrent](https://www.qbittorrent.org) — the engine and everything that makes it reliable
- [libtorrent](https://libtorrent.org) by Arvid Norberg — the BitTorrent implementation
- [Qt](https://www.qt.io) — the framework the interface is built with
- [mpv](https://mpv.io) — the player behind the built-in player
- [QWindowKit](https://github.com/stdware/qwindowkit) — the frameless window with native snapping
- [JacRed](https://jac.red) — the movie & TV search source
- Posters from [IMDb](https://www.imdb.com), [Wikipedia](https://www.wikipedia.org) and [Shikimori](https://shikimori.io)
- Fonts [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) and [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); icons in the style of [Lucide](https://lucide.dev)

## 📄 License

Flux, like qBittorrent, is free software under the [GNU General Public License v2.0 or later](COPYING), with the OpenSSL linking exception. See [`COPYING`](COPYING), [`COPYING.GPLv2`](COPYING.GPLv2) and [`COPYING.GPLv3`](COPYING.GPLv3).

<p align="center"><sub>Made with care for people who just want their torrents to work — and look good doing it.</sub></p>
