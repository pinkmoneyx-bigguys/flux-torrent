<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <b>Polski</b> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Logo Flux Torrent">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Klient torrent, na który naprawdę miło się patrzy.</b><br>
  Niezawodny rdzeń qBittorrent, zupełnie nowy interfejs i odtwarzacz, który włącza film jeszcze w trakcie pobierania.
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
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Pobierz na Windows</b></a>
  &nbsp;·&nbsp;
  <a href="#-funkcje">Funkcje</a>
  &nbsp;·&nbsp;
  <a href="#-zrzuty-ekranu">Zrzuty ekranu</a>
  &nbsp;·&nbsp;
  <a href="#-faq">FAQ</a>
  &nbsp;·&nbsp;
  <a href="#-kompilacja-ze-źródeł">Kompilacja</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent: ekran Transfery z wykresem prędkości na żywo" width="100%">
</p>

---

## 💡 Dlaczego Flux

qBittorrent to najbardziej niezawodny otwartoźródłowy silnik torrentowy, jaki istnieje — a mimo to wciąż wygląda jak z 2010 roku.
Flux zostawia ten silnik **nietknięty** (qBittorrent 5.2.4 na libtorrent 2.0) i buduje wokół niego nowoczesną aplikację dla Windows:

- 🎬 **Najpierw oglądaj, potem pobieraj.** Włącz odtwarzanie torrenta, a film ruszy po kilku sekundach — Flux pobiera najpierw te części, które zaraz zobaczysz.
- 🔎 **Wyszukiwanie, które rozumie filmy.** Wyniki są pogrupowane według filmów: z plakatami, rokiem produkcji i wszystkimi wydaniami na jednej karcie.
- ✨ **Spokojny, szybki interfejs.** Ciemny, przejrzysty i płynny, z wykresami na żywo i liczbami, które przewijają się zamiast migać.
- 🧳 **Nic nie tracisz.** Torrenty i ustawienia z qBittorrent przeniesiesz jednym kliknięciem przy pierwszym uruchomieniu.

## ✨ Funkcje

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Wbudowany odtwarzacz i strumieniowanie</h3>
      Odtwarzaj wideo, zanim torrent skończy się pobierać. Flux w pierwszej kolejności pobiera części tuż przed miejscem odtwarzania, uczciwie pokazuje stan bufora i pamięta, gdzie skończyłeś.
      <br><br>
      <b>Oglądaj bez pobierania</b> trzyma film w tymczasowej pamięci podręcznej i czyści ją, gdy skończysz — nic nie zalega na dysku.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Wyszukiwarka z plakatami</h3>
      Wbudowane źródło filmów i seriali (JacRed) działa od razu, bez Pythona, obok klasycznych wtyczek wyszukiwania qBittorrent.
      <br><br>
      Wyniki zamieniają się w <b>karty filmów</b>: plakaty z serwisów IMDb, Wikipedia i Shikimori, wszystkie wydania filmu w jednym miejscu, przełączniki „Z seedami” i „Z plakatami”, widok listy lub siatki.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Transfery, które mówią, co się dzieje</h3>
      Dwulinijkowe wiersze z czytelnymi statusami, wykres prędkości na żywo dla każdego torrenta, płynnie zmieniające się liczby, kolumny o regulowanej szerokości i panel szczegółów z częściami, plikami, trackerami i partnerami.
      <br><br>
      Świeżo uruchomiony torrent pokazuje <i>„Łączenie z partnerami…”</i>, zamiast wyglądać na zawieszony.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Biblioteka mediów</h3>
      Każde wideo z Twoich torrentów, podzielone na filmy i seriale z sezonami i odcinkami, z oznaczeniami jakości i postępem — gotowe do odtworzenia z jednego ekranu.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS z automatycznym pobieraniem</h3>
      Kanały i foldery, przejrzysty czytnik artykułów oraz reguły, które same pobiorą nowe odcinki, gdy tylko się pojawią.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Stworzony do pracy z klawiaturą</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> otwiera paletę poleceń do wszystkiego: dodanie torrenta, przejście do wybranej strony, włączanie limitów prędkości, sprawdzanie aktualizacji…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Aktualizuje się sam</h3>
      Przy uruchomieniu Flux sprawdza nowe wydania w serwisie GitHub. Jedno kliknięcie w <b>Zaktualizuj i uruchom ponownie</b> pobiera nową wersję, weryfikuje jej sumę kontrolną SHA-256, podmienia pliki i ponownie uruchamia aplikację.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Mówi Twoim językiem</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski i 简体中文. Zmiana języka trwa sekundę, bez restartu, a liczby i daty dostosowują się do wybranego języka.
    </td>
  </tr>
</table>

A wszystko, czego oczekujesz od qBittorrent, nadal tu jest: pobieranie sekwencyjne i najpierw pierwszej oraz ostatniej części, kategorie, limity prędkości z harmonogramem, kolejka, DHT / PeX / LSD, szyfrowanie, serwery proxy, UPnP / NAT-PMP, tworzenie torrentów i pełen zestaw zaawansowanych ustawień libtorrent.

## 📸 Zrzuty ekranu

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Wyszukiwarka"><p align="center"><sub>Wyszukiwarka</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Biblioteka mediów"><p align="center"><sub>Biblioteka mediów</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="Kanały RSS"><p align="center"><sub>Kanały RSS i czytnik artykułów</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Ustawienia języka"><p align="center"><sub>Dziewięć języków, przełączanych w locie</sub></p></td>
  </tr>
</table>

## 🚀 Pierwsze kroki

Pobierz jeden z dwóch plików z [najnowszego wydania](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest):

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** — *zalecany* | Instalator w stylu Flux. Instaluje program tylko dla Ciebie, więc uprawnienia administratora nie są potrzebne; dodaje skróty w menu Start i na pulpicie, otwiera pliki `.torrent` i odnośniki magnet oraz pojawia się na liście *Zainstalowane aplikacje*, skąd można go usunąć. Nowe wersje instalują się w miejsce poprzedniej. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | Wersja przenośna. Rozpakuj ją w dowolnym miejscu — może to być nawet pendrive — i uruchom `Flux.exe`. Ustawienia i torrenty zostają w jej folderze `profile`, a aktualizuje się ona również sama. |

Przy pierwszym uruchomieniu Flux zaproponuje **przeniesienie torrentów i ustawień z qBittorrent**. Najpierw zamknij qBittorrent, a potem kliknij *Przenieś*. Wolisz zacząć z czystą kartą? Wybierz *Zacznij od nowa*.

**Wymagania:** Windows 10 (1809 lub nowszy) albo Windows 11, 64-bitowy. Niczego więcej nie trzeba instalować: Flux ma ze sobą wszystko, czego potrzebuje.

## ⌨️ Skróty klawiszowe

| Skrót | Działanie | | W odtwarzaczu | Działanie |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Paleta poleceń | | <kbd>Space</kbd> | Odtwarzanie / pauza |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Dodaj plik torrent | | <kbd>←</kbd> <kbd>→</kbd> | Przewiń do tyłu / do przodu |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Transfery, Wyszukiwarka, RSS, Biblioteka | | <kbd>↑</kbd> <kbd>↓</kbd> | Głośność |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Ustawienia | | <kbd>M</kbd> | Wycisz |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Zwiń panel boczny | | <kbd>F</kbd> | Pełny ekran |
| | | | <kbd>Esc</kbd> | Wyjdź z odtwarzacza |

## ❓ FAQ

<details>
<summary><b>Czy Flux to fork qBittorrent?</b></summary>
<br>
Tak. Silnik — sesje, dane wznawiania, trackery i sam protokół BitTorrent — to qBittorrent 5.2.4 na libtorrent 2.0.11. Flux zastępuje interfejs nowym, napisanym w Qt Quick (QML), i dokłada do tego strumieniowanie, odtwarzacz, bibliotekę mediów, wyszukiwanie filmów i automatyczne aktualizacje.
</details>

<details>
<summary><b>Czy Flux namiesza w moim qBittorrent?</b></summary>
<br>
Nie. Flux ma własny profil (<code>%APPDATA%\Flux</code> i <code>%LOCALAPPDATA%\Flux</code>). Migracja <i>kopiuje</i> torrenty i ustawienia z qBittorrent, a oryginalny profil zostaje nietknięty. Tylko nie uruchamiaj tych samych torrentów w obu aplikacjach jednocześnie.
</details>

<details>
<summary><b>Dlaczego po kliknięciu „Uruchom” torrent rozpędza się dopiero po kilku sekundach?</b></summary>
<br>
Zatrzymanie torrenta zamyka jego połączenia. Po ponownym uruchomieniu Flux znów łączy się z partnerami, a to od nich zależy, kiedy zaczną wysyłać dane — większość klientów podejmuje tę decyzję co 10–15 sekund. W tym czasie Flux pokazuje <i>„Łączenie z partnerami…”</i>. qBittorrent zachowuje się dokładnie tak samo.
</details>

<details>
<summary><b>Windows nazywa instalator „nierozpoznaną aplikacją”. Czy to bezpieczne?</b></summary>
<br>
SmartScreen ostrzega przed każdym nowym programem, który nie ma jeszcze płatnego certyfikatu podpisywania kodu, a Flux go nie ma. Kliknij <i>Więcej informacji</i> → <i>Uruchom mimo to</i>. Aby upewnić się, że plik jest tym opublikowanym tutaj, porównaj jego SHA-256 z <code>SHA256SUMS.txt</code> w wydaniu (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> w PowerShell).
</details>

<details>
<summary><b>Jak usunąć Flux?</b></summary>
<br>
Otwórz <i>Ustawienia → Aplikacje → Zainstalowane aplikacje</i>, znajdź <b>Flux Torrent</b> i wybierz <i>Odinstaluj</i>. Deinstalator zapyta, czy zachować Twoje ustawienia i listę torrentów; pobrane pliki nigdy nie są ruszane. Wersja przenośna to po prostu folder: usuń go.
</details>

<details>
<summary><b>Czy do wyszukiwania potrzebny jest Python?</b></summary>
<br>
Nie do wbudowanego źródła filmów i seriali. Python jest potrzebny tylko do klasycznych wtyczek wyszukiwania qBittorrent — tak samo jak w samym qBittorrent.
</details>

<details>
<summary><b>Czy jest Web UI albo wersja na Linuksa lub macOS?</b></summary>
<br>
Na razie Flux działa tylko w systemie Windows. Web UI z qBittorrent nadal jest wbudowany (domyślnie wyłączony; można go włączyć w pliku konfiguracyjnym).
</details>

<details>
<summary><b>Czy to legalne?</b></summary>
<br>
BitTorrent to technologia wymiany plików, używana na co dzień do pobierania dystrybucji Linuksa, gier, otwartych filmów i kopii zapasowych. Flux jest klientem, jak każdy inny. Za to, co pobierasz i udostępniasz, odpowiadasz sam — przestrzegaj prawa swojego kraju.
</details>

## 🛠 Kompilacja ze źródeł

<details>
<summary><b>Pokaż kroki</b></summary>
<br>

Wszystko załatwiają skrypty PowerShell. Pierwszy z nich instaluje narzędzia (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg z OpenSSL, zlib, Boost 1.90 i libtorrent 2.0.11, libmpv) i zapisuje ich wersje w <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Narzędzia i zależności (uruchom raz, w PowerShell z uprawnieniami administratora)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Zbuduj interfejs QML i uruchom testy
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Umieść w deploy\ gotową do uruchomienia kopię razem z Qt i bibliotekami DLL
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Przygotuj wydanie w dist\: instalator, przenośne archiwum zip, sumy kontrolne i informacje o wydaniu
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Opublikuj pliki z <code>dist\</code> w wydaniu na GitHub z tagiem <code>v&lt;version&gt;</code> (zobacz <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>) — a każdy Flux zaproponuje aktualizację: zainstalowany pobierze instalator, przenośny — archiwum zip.

**Struktura projektu**

| Ścieżka | Co się tam znajduje |
|---|---|
| `src/base`, `src/app` | Silnik i aplikacja qBittorrent, możliwie zbliżone do wersji upstream |
| `src/qmlgui/qml` | Interfejs: strony, kontrolki, odtwarzacz |
| `src/qmlgui/backend` | Modele C++, z których korzysta interfejs (torrenty, wyszukiwanie, plakaty, RSS, aktualizacje, języki…) |
| `src/qmlgui/streaming` | Strumieniowanie: planowanie odczytu z wyprzedzeniem i lokalny serwer strumieniowy |
| `src/qmlgui/i18n` | Tłumaczenia (`flux_<code>.ts`) |
| `src/installer` | Instalator: samorozpakowujący się stub bez zależności i jego interfejs w QML |
| `test/qmlgui` | Testy C++ i QML |

</details>

## 🌍 Tłumaczenia

Flux jest przetłumaczony na 9 języków. Teksty znajdują się w [`src/qmlgui/i18n`](../../src/qmlgui/i18n) jako pliki Qt `.ts`, po jednym na język; można je otworzyć w Qt Linguist lub w dowolnym edytorze tekstu.

Trafiłeś na niezręczne sformułowanie albo chcesz dodać swój język? [Zgłoś problem](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) lub wyślij pull request — [`CONTRIBUTING.md`](../../CONTRIBUTING.md) pokazuje, gdzie co leży, a kontrola przy każdym pull requeście sprawdza, czy każde tłumaczenie jest kompletne i zachowuje wszystkie symbole zastępcze.

## 🤝 Współtworzenie

Zgłoszenia błędów, pomysły i pull requesty są mile widziane — szczegóły znajdziesz w [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Zanim otworzysz pull request, uruchom testy:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Podziękowania

Flux stoi na ramionach wspaniałych projektów open source:

- [qBittorrent](https://www.qbittorrent.org) — silnik i wszystko, co czyni go niezawodnym
- [libtorrent](https://libtorrent.org) autorstwa Arvida Norberga — implementacja protokołu BitTorrent
- [Qt](https://www.qt.io) — framework, na którym zbudowano interfejs
- [mpv](https://mpv.io) — silnik wbudowanego odtwarzacza
- [QWindowKit](https://github.com/stdware/qwindowkit) — okno bez ramki z natywnym przyciąganiem do krawędzi ekranu
- [JacRed](https://jac.red) — źródło wyszukiwania filmów i seriali
- Plakaty z serwisów [IMDb](https://www.imdb.com), [Wikipedia](https://www.wikipedia.org) i [Shikimori](https://shikimori.io)
- Fonty [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) i [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); ikony w stylu [Lucide](https://lucide.dev)

## 📄 Licencja

Flux, podobnie jak qBittorrent, jest wolnym oprogramowaniem na licencji [GNU General Public License v2.0 lub nowszej](../../COPYING), z wyjątkiem dotyczącym linkowania z OpenSSL. Zobacz [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) i [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Stworzone z myślą o tych, którzy po prostu chcą, żeby torrenty działały — i przy okazji dobrze wyglądały.</sub></p>
