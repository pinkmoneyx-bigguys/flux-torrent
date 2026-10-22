<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <b>Deutsch</b> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.pl.md">Polski</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Flux-Torrent-Logo">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Ein Torrent-Client, den Sie sich gern ansehen werden.</b><br>
  Der grundsolide Kern von qBittorrent, eine völlig neue Oberfläche und ein Player, der den Film schon während des Downloads startet.
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><img src="https://img.shields.io/github/v/release/pinkmoneyx-bigguys/flux-torrent?style=flat-square&color=4f8cff&label=release" alt="Latest release"></a>
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases"><img src="https://img.shields.io/github/downloads/pinkmoneyx-bigguys/flux-torrent/total?style=flat-square&color=22c55e&label=downloads" alt="Downloads"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0a0a0a?style=flat-square&logo=windows11&logoColor=white" alt="Windows 10 and 11">
  <img src="https://img.shields.io/badge/core-qBittorrent%205.2.4-2f67ba?style=flat-square&logo=qbittorrent&logoColor=white" alt="qBittorrent 5.2.4 core">
  <img src="https://img.shields.io/badge/UI-Qt%206.10%20%2B%20QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="Qt 6.10">
  <img src="https://img.shields.io/badge/languages-9-ff7a59?style=flat-square" alt="9 languages">
  <a href="../../COPYING"><img src="https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square" alt="License: GPL-2.0-or-later"></a>
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Für Windows herunterladen</b></a>
  &nbsp;·&nbsp;
  <a href="https://pinkmoneyx-bigguys.github.io/flux-torrent/"><b>Website</b></a>
  &nbsp;·&nbsp;
  <a href="#-funktionen">Funktionen</a>
  &nbsp;·&nbsp;
  <a href="#-screenshots">Screenshots</a>
  &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#-aus-dem-quellcode-bauen">Selbst bauen</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent: der Bildschirm „Übertragungen“ mit Live-Geschwindigkeitsdiagramm" width="100%">
</p>

---

## 💡 Warum Flux

qBittorrent ist die zuverlässigste Open-Source-Torrent-Engine überhaupt – und sieht noch immer aus wie 2010.
Flux lässt diese Engine **unangetastet** (qBittorrent 5.2.4 auf libtorrent 2.0) und baut eine moderne Windows-App drumherum:

- 🎬 **Erst schauen, dann laden.** Starten Sie die Wiedergabe eines Torrents, und der Film läuft nach Sekunden – Flux holt die Teile, die Sie gleich sehen, vor allen anderen.
- 🔎 **Eine Suche, die Filme versteht.** Die Ergebnisse sind nach Film gruppiert, mit Postern, Erscheinungsjahr und allen Releases in einer Karte.
- ✨ **Eine ruhige, schnelle Oberfläche.** Dunkel, aufgeräumt und flüssig, mit Live-Diagrammen und Zahlen, die weiterrollen statt zu flackern.
- 🧳 **Nichts geht verloren.** Ihre Torrents und Einstellungen aus qBittorrent ziehen beim ersten Start mit einem Klick um.

## ✨ Funktionen

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Integrierter Player & Streaming</h3>
      Spielen Sie ein Video ab, während der Torrent noch lädt. Flux fordert zuerst die Teile direkt vor der Abspielposition an, zeigt ehrlich, wie viel gepuffert ist, und merkt sich, wo Sie aufgehört haben.
      <br><br>
      <b>Ohne Download ansehen</b> hält einen Film in einem temporären Cache und leert ihn, sobald Sie fertig sind – auf Ihrer Festplatte sammelt sich nichts an.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Tracker-Suche mit Postern</h3>
      Eine integrierte Quelle für Filme und Serien (JacRed) funktioniert sofort – ganz ohne Python – neben den klassischen Such-Plugins von qBittorrent.
      <br><br>
      Aus Ergebnissen werden <b>Filmkarten</b>: Poster von IMDb, Wikipedia und Shikimori, alle Releases eines Films an einem Ort, die Schalter „Mit Seeds“ und „Mit Postern“, als Liste oder Raster.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Übertragungen, die zeigen, was los ist</h3>
      Zweizeilige Einträge mit klarem Status, ein Live-Geschwindigkeitsdiagramm pro Torrent, rollende Geschwindigkeitswerte, anpassbare Spalten und ein Detailbereich mit Teilen, Dateien, Trackern und Peers.
      <br><br>
      Ein gerade gestarteter Torrent zeigt <i>„Verbindet mit Peers…“</i>, statt festzuhängen zu scheinen.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Mediathek</h3>
      Jedes Video aus Ihren Torrents, sortiert nach Filmen und Serien mit Staffeln und Folgen, Qualitätsangaben und Fortschritt – abspielbereit auf einem Bildschirm.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS mit Auto-Download</h3>
      Feeds und Ordner, ein übersichtlicher Artikel-Reader und Regeln, die neue Folgen für Sie holen, sobald sie erscheinen.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Für die Tastatur gemacht</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> öffnet eine Befehlspalette für alles: Torrent hinzufügen, zu einer Seite springen, Geschwindigkeitslimits umschalten, nach Updates suchen…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Aktualisiert sich selbst</h3>
      Flux prüft beim Start die Releases auf GitHub. Ein Klick auf <b>Aktualisieren und neu starten</b> lädt die neue Version herunter, prüft ihre SHA-256-Prüfsumme, installiert sie und startet Flux neu.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Spricht Ihre Sprache</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski und 简体中文. Der Wechsel dauert eine Sekunde – ohne Neustart –, und Zahlen und Datumsangaben folgen der Sprache.
    </td>
  </tr>
</table>

Und alles, was Sie von qBittorrent erwarten, ist weiterhin da: sequenzieller Download und erste/letzte Teile zuerst, Kategorien, Geschwindigkeitslimits mit Zeitplan, die Warteschlange, DHT / PeX / LSD, Verschlüsselung, Proxys, UPnP / NAT-PMP, Torrent-Erstellung und sämtliche erweiterten libtorrent-Einstellungen.

## 📸 Screenshots

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Tracker-Suche"><p align="center"><sub>Tracker-Suche</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Mediathek"><p align="center"><sub>Mediathek</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="RSS-Feeds"><p align="center"><sub>RSS-Feeds und Artikel-Reader</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Spracheinstellungen"><p align="center"><sub>Neun Sprachen, im laufenden Betrieb umschaltbar</sub></p></td>
  </tr>
</table>

## 🚀 Erste Schritte

Laden Sie eine der beiden Dateien aus dem [neuesten Release](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest) herunter:

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** – *empfohlen* | Das Setup im eigenen Look von Flux. Es installiert nur für Sie, daher sind keine Administratorrechte nötig; legt Verknüpfungen im Startmenü und auf dem Desktop an, öffnet `.torrent`-Dateien und Magnet-Links und erscheint unter *Installierte Apps*, wo Sie es wieder entfernen können. Neue Versionen werden direkt an Ort und Stelle aktualisiert. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | Die portable Version. Entpacken Sie sie an einen beliebigen Ort – auch ein USB-Stick geht – und starten Sie `Flux.exe`. Einstellungen und Torrents bleiben in ihrem Ordner `profile`, und auch sie aktualisiert sich selbst. |

Beim ersten Start bietet Flux an, **Ihre Torrents und Einstellungen aus qBittorrent zu übernehmen**. Schließen Sie zuerst qBittorrent und klicken Sie dann auf *Übernehmen*. Lieber ganz von vorn? Wählen Sie *Neu beginnen*.

**Systemvoraussetzungen:** Windows 10 (1809 oder neuer) oder Windows 11, 64-Bit. Sonst ist nichts zu installieren: Flux bringt alles mit, was es braucht.

## ⌨️ Tastenkürzel

| Kürzel | Aktion | | Im Player | Aktion |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Befehlspalette | | <kbd>Space</kbd> | Abspielen / Pause |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Torrent-Datei hinzufügen | | <kbd>←</kbd> <kbd>→</kbd> | Zurück- / vorspulen |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Übertragungen, Tracker-Suche, RSS, Mediathek | | <kbd>↑</kbd> <kbd>↓</kbd> | Lautstärke |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Einstellungen | | <kbd>M</kbd> | Stumm |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Seitenleiste einklappen | | <kbd>F</kbd> | Vollbild |
| | | | <kbd>Esc</kbd> | Player verlassen |

## ❓ FAQ

<details>
<summary><b>Ist Flux ein Fork von qBittorrent?</b></summary>
<br>
Ja. Die Engine – Sitzungen, Fortsetzungsdaten, Tracker, das BitTorrent-Protokoll selbst – ist qBittorrent 5.2.4 auf libtorrent 2.0.11. Flux ersetzt die Oberfläche durch eine neue in Qt Quick (QML) und ergänzt Streaming, den Player, die Mediathek, die Filmsuche und den Updater.
</details>

<details>
<summary><b>Bringt Flux mein qBittorrent durcheinander?</b></summary>
<br>
Nein. Flux nutzt ein eigenes Profil (<code>%APPDATA%\Flux</code> und <code>%LOCALAPPDATA%\Flux</code>). Die Übernahme <i>kopiert</i> Ihre Torrents und Einstellungen aus qBittorrent; das ursprüngliche Profil bleibt unverändert. Lassen Sie nur nicht dieselben Torrents gleichzeitig in beiden Apps laufen.
</details>

<details>
<summary><b>Warum dauert es nach „Starten“ ein paar Sekunden, bis ein Torrent Fahrt aufnimmt?</b></summary>
<br>
Beim Stoppen eines Torrents werden seine Verbindungen geschlossen. Beim Start nimmt Flux wieder Kontakt zu den Peers auf, und die entscheiden selbst, wann sie mit dem Senden beginnen – die meisten Clients prüfen das alle 10–15 Sekunden neu. Bis dahin zeigt Flux <i>„Verbindet mit Peers…“</i>. qBittorrent verhält sich genauso.
</details>

<details>
<summary><b>Windows nennt das Setup eine „unbekannte App“. Ist es sicher?</b></summary>
<br>
SmartScreen warnt vor jedem neuen Programm, das noch kein kostenpflichtiges Code-Signing-Zertifikat hat – und Flux hat keins. Klicken Sie auf <i>Weitere Informationen</i> → <i>Trotzdem ausführen</i>. Um sicherzugehen, dass die Datei die hier veröffentlichte ist, vergleichen Sie ihren SHA-256-Hash mit <code>SHA256SUMS.txt</code> im Release (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> in PowerShell).
</details>

<details>
<summary><b>Wie entferne ich Flux?</b></summary>
<br>
Öffnen Sie <i>Einstellungen → Apps → Installierte Apps</i>, suchen Sie <b>Flux Torrent</b> und wählen Sie <i>Deinstallieren</i>. Das Deinstallationsprogramm fragt, ob Ihre Einstellungen und die Torrent-Liste erhalten bleiben sollen; heruntergeladene Dateien werden nie angerührt. Die portable Version ist nur ein Ordner: Löschen Sie ihn einfach.
</details>

<details>
<summary><b>Brauche ich Python für die Suche?</b></summary>
<br>
Nicht für die integrierte Quelle für Filme und Serien. Python wird nur für die klassischen Such-Plugins von qBittorrent benötigt – genau wie in qBittorrent.
</details>

<details>
<summary><b>Gibt es eine Web-UI, eine Linux- oder eine macOS-Version?</b></summary>
<br>
Flux gibt es vorerst nur für Windows. Die Web-UI von qBittorrent ist weiterhin eingebaut (standardmäßig deaktiviert; sie lässt sich in der Konfigurationsdatei einschalten).
</details>

<details>
<summary><b>Ist das legal?</b></summary>
<br>
BitTorrent ist eine Technik zum Teilen von Dateien und wird täglich für Linux-Distributionen, Spiele, freie Filme und Backups genutzt. Flux ist ein Client wie jeder andere. Was Sie herunterladen und teilen, liegt in Ihrer Verantwortung – bitte halten Sie sich an die Gesetze Ihres Landes.
</details>

## 🛠 Aus dem Quellcode bauen

<details>
<summary><b>Schritte anzeigen</b></summary>
<br>

Alles ist in PowerShell geskriptet. Das erste Skript installiert die Toolchain (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg mit OpenSSL, zlib, Boost 1.90 und libtorrent 2.0.11, libmpv) und legt die Versionen in <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a> fest.

```powershell
# 1. Toolchain und Abhängigkeiten (einmalig, in einer PowerShell mit Administratorrechten)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. QML-Oberfläche bauen und Tests ausführen
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Lauffähige Kopie samt Qt und DLLs in deploy\ ablegen
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Ein Release in dist\: das Setup, das portable Zip, Prüfsummen und Release Notes
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Veröffentlichen Sie die Dateien aus <code>dist\</code> in einem GitHub-Release mit dem Tag <code>v&lt;version&gt;</code> (siehe <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>) – dann bietet jedes Flux da draußen das Update an: ein installiertes nimmt das Setup, ein portables das Zip.

**Projektstruktur**

| Pfad | Inhalt |
|---|---|
| `src/base`, `src/app` | Engine und Anwendung von qBittorrent, nah am Upstream gehalten |
| `src/qmlgui/qml` | Die Oberfläche: Seiten, Steuerelemente, der Player |
| `src/qmlgui/backend` | C++-Modelle, mit denen die Oberfläche spricht (Torrents, Suche, Poster, RSS, Updates, Sprachen…) |
| `src/qmlgui/streaming` | Streaming: Planung des Vorausladens und der lokale Stream-Server |
| `src/qmlgui/i18n` | Übersetzungen (`flux_<code>.ts`) |
| `src/installer` | Das Setup: ein selbstentpackender Stub ohne Abhängigkeiten und seine QML-Oberfläche |
| `test/qmlgui` | C++- und QML-Tests |

</details>

## 🌍 Übersetzungen

Flux ist in 9 Sprachen übersetzt. Die Texte liegen in [`src/qmlgui/i18n`](../../src/qmlgui/i18n) als Qt-`.ts`-Dateien, eine pro Sprache, und lassen sich in Qt Linguist oder jedem Texteditor öffnen.

Eine holprige Formulierung entdeckt oder fehlt Ihre Sprache? [Eröffnen Sie ein Issue](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) oder schicken Sie einen Pull Request – [`CONTRIBUTING.md`](../../CONTRIBUTING.md) zeigt, wo was liegt, und eine Prüfung bei jedem Pull Request stellt sicher, dass jede Übersetzung vollständig ist und ihre Platzhalter behält.

## 🤝 Mitwirken

Fehlerberichte, Ideen und Pull Requests sind willkommen – Details stehen in [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Bitte führen Sie vor einem Pull Request die Tests aus:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Danksagungen

Flux steht auf den Schultern großartiger Open-Source-Projekte:

- [qBittorrent](https://www.qbittorrent.org) – die Engine und alles, was sie zuverlässig macht
- [libtorrent](https://libtorrent.org) von Arvid Norberg – die BitTorrent-Implementierung
- [Qt](https://www.qt.io) – das Framework, mit dem die Oberfläche gebaut ist
- [mpv](https://mpv.io) – die Basis des integrierten Players
- [QWindowKit](https://github.com/stdware/qwindowkit) – das rahmenlose Fenster mit nativem Andocken
- [JacRed](https://jac.red) – die Suchquelle für Filme und Serien
- Poster von [IMDb](https://www.imdb.com), [Wikipedia](https://www.wikipedia.org) und [Shikimori](https://shikimori.io)
- Schriften [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) und [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); Icons im Stil von [Lucide](https://lucide.dev)

## 📄 Lizenz

Flux ist wie qBittorrent freie Software unter der [GNU General Public License v2.0 oder neuer](../../COPYING), mit der OpenSSL-Linking-Ausnahme. Siehe [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) und [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Mit Sorgfalt gemacht für alle, die einfach wollen, dass ihre Torrents funktionieren – und dabei gut aussehen.</sub></p>
