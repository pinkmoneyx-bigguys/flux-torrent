<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <b>Français</b> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.pl.md">Polski</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Logo de Flux Torrent">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Un client torrent qu’on prend vraiment plaisir à regarder.</b><br>
  Le moteur à toute épreuve de qBittorrent, une interface entièrement repensée et un lecteur qui lance le film pendant le téléchargement.
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
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Télécharger pour Windows</b></a>
  &nbsp;·&nbsp;
  <a href="https://pinkmoneyx-bigguys.github.io/flux-torrent/"><b>Site web</b></a>
  &nbsp;·&nbsp;
  <a href="#-fonctionnalités">Fonctionnalités</a>
  &nbsp;·&nbsp;
  <a href="#-captures-décran">Captures d’écran</a>
  &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#-compiler-depuis-les-sources">Compilation</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent : l’écran Transferts avec un graphique de vitesse en direct" width="100%">
</p>

---

## 💡 Pourquoi Flux

qBittorrent est le moteur torrent open source le plus fiable qui soit — et il a toujours l’air de sortir de 2010.
Flux garde ce moteur **intact** (qBittorrent 5.2.4 sur libtorrent 2.0) et bâtit autour une application Windows moderne :

- 🎬 **Regardez d’abord, téléchargez ensuite.** Lancez la lecture d’un torrent et le film démarre en quelques secondes — Flux récupère les morceaux que vous allez voir avant tout le reste.
- 🔎 **Une recherche qui s’y connaît en cinéma.** Les résultats sont regroupés par film, avec l’affiche, l’année et toutes les versions réunies sur une seule fiche.
- ✨ **Une interface sereine et rapide.** Sombre, épurée et fluide, avec des graphiques en direct et des chiffres qui défilent au lieu de clignoter.
- 🧳 **Rien à perdre.** Vos torrents et paramètres qBittorrent vous suivent en un clic dès le premier lancement.

## ✨ Fonctionnalités

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Lecteur intégré et streaming</h3>
      Regardez une vidéo pendant que le torrent se télécharge encore. Flux demande en priorité les morceaux situés juste devant la tête de lecture, affiche une jauge de tampon fidèle et se souvient de l’endroit où vous vous êtes arrêté.
      <br><br>
      <b>Regarder sans télécharger</b> garde le film dans un cache temporaire et le vide une fois que vous avez terminé — rien ne s’entasse sur votre disque.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Recherche de torrents avec affiches</h3>
      Une source films et séries intégrée (JacRed) fonctionne d’emblée — sans Python — aux côtés des plugins de recherche classiques de qBittorrent.
      <br><br>
      Les résultats deviennent des <b>fiches de film</b> : affiches trouvées sur IMDb, Wikipedia et Shikimori, toutes les versions d’un film au même endroit, filtres « Avec sources » et « Avec affiches », affichage en liste ou en grille.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Des transferts qui vous disent ce qui se passe</h3>
      Des lignes sur deux niveaux aux statuts clairs, un graphique de vitesse en direct pour chaque torrent, des vitesses qui défilent, des colonnes redimensionnables et un panneau de détails avec morceaux, fichiers, trackers et pairs.
      <br><br>
      Un torrent que vous venez de démarrer affiche <i>« Connexion aux pairs… »</i> au lieu d’avoir l’air bloqué.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Médiathèque</h3>
      Toutes les vidéos de vos torrents, classées en films et en séries avec saisons et épisodes, badges de qualité et progression — prêtes à être lues depuis un seul écran.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS avec téléchargement automatique</h3>
      Des flux et des dossiers, un lecteur d’articles épuré et des règles qui récupèrent pour vous les nouveaux épisodes dès leur sortie.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Pensé pour le clavier</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> ouvre une palette de commandes qui donne accès à tout : ajouter un torrent, changer de page, activer ou couper les limites de vitesse, rechercher des mises à jour…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Se met à jour tout seul</h3>
      Au démarrage, Flux consulte les versions publiées sur GitHub. Un clic sur <b>Mettre à jour et redémarrer</b> télécharge la nouvelle version, vérifie sa somme de contrôle SHA-256, la met en place et relance l’application.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Parle votre langue</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski et 简体中文. Changer de langue prend une seconde — sans redémarrage — et les nombres comme les dates suivent la langue choisie.
    </td>
  </tr>
</table>

Et tout ce que vous attendez de qBittorrent est toujours là : téléchargement dans l’ordre et premiers et derniers morceaux d’abord, catégories, limites de vitesse planifiées, file d’attente, DHT / PeX / LSD, chiffrement, proxys, UPnP / NAT-PMP, création de torrents et l’ensemble des réglages avancés de libtorrent.

## 📸 Captures d’écran

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Recherche de torrents"><p align="center"><sub>Recherche de torrents</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Médiathèque"><p align="center"><sub>Médiathèque</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="Flux RSS"><p align="center"><sub>Les flux RSS et le lecteur d’articles</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Paramètres de langue"><p align="center"><sub>Neuf langues, à changer à la volée</sub></p></td>
  </tr>
</table>

## 🚀 Prise en main

Téléchargez l’un des deux fichiers depuis la [dernière version](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest) :

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** — *recommandé* | Le programme d’installation, aux couleurs de Flux. Il installe Flux pour vous seul, sans droits d’administrateur ; il ajoute des raccourcis dans le menu Démarrer et sur le bureau, ouvre les fichiers `.torrent` et les liens magnet, et apparaît dans *Applications installées* pour pouvoir le désinstaller. Les nouvelles versions s’installent par-dessus l’ancienne. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | La version portable. Décompressez-la où vous voulez — une clé USB fait l’affaire — et lancez `Flux.exe`. Paramètres et torrents restent dans son dossier `profile`, et elle se met à jour toute seule, elle aussi. |

Au premier lancement, Flux propose de **reprendre vos torrents et paramètres de qBittorrent**. Fermez d’abord qBittorrent, puis cliquez sur *Migrer*. Vous préférez partir d’une page blanche ? Choisissez *Repartir de zéro*.

**Configuration requise :** Windows 10 (1809 ou plus récent) ou Windows 11, 64 bits. Rien d’autre à installer : Flux embarque tout ce dont il a besoin.

## ⌨️ Raccourcis clavier

| Raccourci | Action | | Dans le lecteur | Action |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Palette de commandes | | <kbd>Space</kbd> | Lecture / pause |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Ajouter un fichier torrent | | <kbd>←</kbd> <kbd>→</kbd> | Reculer / avancer |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Transferts, Recherche, RSS, Médiathèque | | <kbd>↑</kbd> <kbd>↓</kbd> | Volume |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Paramètres | | <kbd>M</kbd> | Couper le son |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Replier la barre latérale | | <kbd>F</kbd> | Plein écran |
| | | | <kbd>Esc</kbd> | Quitter le lecteur |

## ❓ FAQ

<details>
<summary><b>Flux est-il un fork de qBittorrent ?</b></summary>
<br>
Oui. Le moteur — sessions, données de reprise, trackers, le protocole BitTorrent lui-même — est celui de qBittorrent 5.2.4 sur libtorrent 2.0.11. Flux remplace l’interface par une nouvelle, écrite en Qt Quick (QML), et y ajoute le streaming, le lecteur, la médiathèque, la recherche de films et les mises à jour intégrées.
</details>

<details>
<summary><b>Flux risque-t-il de dérégler mon qBittorrent ?</b></summary>
<br>
Non. Flux utilise son propre profil (<code>%APPDATA%\Flux</code> et <code>%LOCALAPPDATA%\Flux</code>). La migration <i>copie</i> vos torrents et paramètres qBittorrent ; le profil d’origine reste tel quel. Évitez simplement de faire tourner les mêmes torrents dans les deux applications à la fois.
</details>

<details>
<summary><b>Pourquoi un torrent met-il quelques secondes à prendre de la vitesse après « Démarrer » ?</b></summary>
<br>
Arrêter un torrent ferme ses connexions. Au démarrage, Flux recontacte les pairs, et c’est à eux de décider quand recommencer à envoyer — la plupart des clients réexaminent ce choix toutes les 10 à 15 secondes. En attendant, Flux affiche <i>« Connexion aux pairs… »</i>. qBittorrent se comporte exactement de la même façon.
</details>

<details>
<summary><b>Windows dit que le programme d’installation est « non reconnu ». Est-il sûr ?</b></summary>
<br>
SmartScreen avertit pour chaque nouveau programme qui n’a pas encore de certificat de signature de code payant, et Flux n’en a pas. Cliquez sur <i>Informations complémentaires</i> → <i>Exécuter quand même</i>. Pour vous assurer que le fichier est bien celui publié ici, comparez son SHA-256 avec <code>SHA256SUMS.txt</code> dans la version (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> dans PowerShell).
</details>

<details>
<summary><b>Comment désinstaller Flux ?</b></summary>
<br>
Ouvrez <i>Paramètres → Applications → Applications installées</i>, trouvez <b>Flux Torrent</b> et choisissez <i>Désinstaller</i>. Le programme de désinstallation demande s’il faut conserver vos paramètres et la liste des torrents ; les fichiers téléchargés ne sont jamais touchés. La version portable n’est qu’un dossier : supprimez-le.
</details>

<details>
<summary><b>Faut-il Python pour la recherche ?</b></summary>
<br>
Pas pour la source films et séries intégrée. Python n’est nécessaire que pour les plugins de recherche classiques de qBittorrent, comme dans qBittorrent.
</details>

<details>
<summary><b>Existe-t-il une interface web, une version Linux ou macOS ?</b></summary>
<br>
Pour l’instant, Flux est réservé à Windows. L’interface web (Web UI) de qBittorrent reste intégrée (désactivée par défaut, elle peut être activée dans le fichier de configuration).
</details>

<details>
<summary><b>Est-ce légal ?</b></summary>
<br>
BitTorrent est une technologie de partage de fichiers, utilisée chaque jour pour les distributions Linux, les jeux, les films libres et les sauvegardes. Flux est un client comme un autre. Ce que vous téléchargez et partagez relève de votre seule responsabilité — merci de respecter les lois de votre pays.
</details>

## 🛠 Compiler depuis les sources

<details>
<summary><b>Afficher les étapes</b></summary>
<br>

Tout est automatisé en PowerShell. Le premier script installe la chaîne de compilation (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg avec OpenSSL, zlib, Boost 1.90 et libtorrent 2.0.11, libmpv) et fige les versions dans <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Chaîne de compilation et dépendances (une seule fois, dans un PowerShell administrateur)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Compiler l’interface QML et lancer les tests
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Placer une copie prête à lancer, avec Qt et ses DLL, dans deploy\
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Préparer une publication dans dist\ — programme d’installation, zip portable, sommes de contrôle et notes de version
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Publiez les fichiers de <code>dist\</code> dans une version GitHub étiquetée <code>v&lt;version&gt;</code> (voir <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>) — chaque Flux en circulation propose alors la mise à jour : une copie installée prend le programme d’installation, une copie portable le zip.

**Organisation du projet**

| Chemin | Contenu |
|---|---|
| `src/base`, `src/app` | Le moteur et l’application de qBittorrent, maintenus au plus près de l’amont |
| `src/qmlgui/qml` | L’interface : pages, contrôles, lecteur |
| `src/qmlgui/backend` | Les modèles C++ avec lesquels l’interface dialogue (torrents, recherche, affiches, RSS, mises à jour, langues…) |
| `src/qmlgui/streaming` | Le streaming : planification de la lecture anticipée et serveur de streaming local |
| `src/qmlgui/i18n` | Les traductions (`flux_<code>.ts`) |
| `src/installer` | Le programme d’installation : un stub auto-extractible sans dépendances et son interface QML |
| `test/qmlgui` | Les tests C++ et QML |

</details>

## 🌍 Traductions

Flux est traduit en 9 langues. Les chaînes se trouvent dans [`src/qmlgui/i18n`](../../src/qmlgui/i18n) sous forme de fichiers Qt `.ts`, un par langue, qui s’ouvrent dans Qt Linguist ou dans n’importe quel éditeur de texte.

Une tournure maladroite vous a fait tiquer, ou vous aimeriez voir votre langue ajoutée ? [Ouvrez un ticket](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) ou envoyez une pull request — [`CONTRIBUTING.md`](../../CONTRIBUTING.md) indique où se trouve chaque chose, et une vérification sur chaque pull request s’assure que chaque traduction est complète et conserve ses espaces réservés.

## 🤝 Contribuer

Rapports de bugs, idées et pull requests sont les bienvenus — [`CONTRIBUTING.md`](../../CONTRIBUTING.md) donne tous les détails. Avant d’ouvrir une pull request, merci de lancer les tests :

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Remerciements

Flux repose sur les épaules de formidables projets open source :

- [qBittorrent](https://www.qbittorrent.org) — le moteur et tout ce qui fait sa fiabilité
- [libtorrent](https://libtorrent.org), d’Arvid Norberg — l’implémentation de BitTorrent
- [Qt](https://www.qt.io) — le framework sur lequel repose l’interface
- [mpv](https://mpv.io) — le moteur qui fait tourner le lecteur intégré
- [QWindowKit](https://github.com/stdware/qwindowkit) — la fenêtre sans bordure avec l’ancrage natif de Windows
- [JacRed](https://jac.red) — la source de recherche films et séries
- Affiches issues d’[IMDb](https://www.imdb.com), de [Wikipedia](https://www.wikipedia.org) et de [Shikimori](https://shikimori.io)
- Polices [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) et [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono) ; icônes dans le style de [Lucide](https://lucide.dev)

## 📄 Licence

Flux, comme qBittorrent, est un logiciel libre distribué sous [GNU General Public License v2.0 ou ultérieure](../../COPYING), avec l’exception de liaison OpenSSL. Voir [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) et [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Conçu avec soin pour celles et ceux qui veulent simplement que leurs torrents marchent — et avec style.</sub></p>
