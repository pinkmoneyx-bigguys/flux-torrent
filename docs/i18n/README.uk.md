<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <b>Українська</b> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.pl.md">Polski</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Логотип Flux Torrent">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Торрент-клієнт, на який приємно дивитися.</b><br>
  Надійне ядро qBittorrent, цілком новий інтерфейс і плеєр, що вмикає фільм, поки той ще завантажується.
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><img src="https://img.shields.io/github/v/release/pinkmoneyx-bigguys/flux-torrent?style=flat-square&color=4f8cff&label=release" alt="Остання версія"></a>
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases"><img src="https://img.shields.io/github/downloads/pinkmoneyx-bigguys/flux-torrent/total?style=flat-square&color=22c55e&label=downloads" alt="Завантаження"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0a0a0a?style=flat-square&logo=windows11&logoColor=white" alt="Windows 10 і 11">
  <img src="https://img.shields.io/badge/core-qBittorrent%205.2.4-2f67ba?style=flat-square&logo=qbittorrent&logoColor=white" alt="Ядро qBittorrent 5.2.4">
  <img src="https://img.shields.io/badge/UI-Qt%206.10%20%2B%20QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="Qt 6.10">
  <img src="https://img.shields.io/badge/languages-9-ff7a59?style=flat-square" alt="9 мов">
  <a href="../../COPYING"><img src="https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square" alt="Ліцензія: GPL-2.0-or-later"></a>
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Завантажити для Windows</b></a>
  &nbsp;·&nbsp;
  <a href="#-можливості">Можливості</a>
  &nbsp;·&nbsp;
  <a href="#-знімки-екрана">Знімки екрана</a>
  &nbsp;·&nbsp;
  <a href="#-часті-запитання">Запитання</a>
  &nbsp;·&nbsp;
  <a href="#-збирання-з-вихідного-коду">Збирання</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent: екран «Передачі» з графіком швидкості наживо" width="100%">
</p>

---

## 💡 Чому Flux

qBittorrent — найнадійніший торрент-рушій з відкритим кодом. І досі виглядає так, ніби на дворі 2010 рік.
Flux залишає цей рушій **недоторканим** (qBittorrent 5.2.4 на libtorrent 2.0) і будує навколо нього сучасну програму для Windows:

- 🎬 **Спершу дивіться, потім завантажуйте.** Натисніть «відтворити» на торренті — і фільм почнеться за лічені секунди: Flux першими підтягує ті частини, які ви от-от побачите.
- 🔎 **Пошук, що розуміється на кіно.** Результати згруповано за фільмами: постери, роки й усі релізи в одній картці.
- ✨ **Спокійний і швидкий інтерфейс.** Темний, охайний і плавний, з живими графіками та цифрами, які прокручуються, а не блимають.
- 🧳 **Нічого не загубиться.** Ваші торренти й налаштування qBittorrent переїжджають одним клацанням під час першого запуску.

## ✨ Можливості

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Вбудований плеєр і стримінг</h3>
      Дивіться відео, поки торрент ще завантажується. Flux насамперед запитує частини, що йдуть просто перед позицією відтворення, чесно показує заповнення буфера й пам’ятає, де ви зупинилися.
      <br><br>
      <b>Дивитися без завантаження</b> — фільм лежить у тимчасовому кеші й зникає, щойно ви закінчите перегляд. На диску нічого не накопичується.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Пошук на трекерах із постерами</h3>
      Вбудоване джерело фільмів і серіалів (JacRed) працює одразу, без Python, поруч із класичними пошуковими плагінами qBittorrent.
      <br><br>
      Результати перетворюються на <b>картки фільмів</b>: постери з IMDb, Wikipedia та Shikimori, усі релізи фільму в одному місці, перемикачі «Із сідами» та «З постерами», список або сітка.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Передачі, які кажуть, що відбувається</h3>
      Дворядкові рядки зі зрозумілими статусами, живий графік швидкості для кожного торрента, плавні цифри швидкості, стовпці змінної ширини й панель подробиць із частинами, файлами, трекерами та пірами.
      <br><br>
      Щойно запущений торрент показує <i>«Підключення до пірів…»</i>, а не здається завислим.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Медіатека</h3>
      Усі відео з ваших торрентів, розкладені на фільми й серіали з сезонами та серіями, позначками якості й прогресом перегляду — усе можна відтворити з одного екрана.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS з автозавантаженням</h3>
      Стрічки й теки, охайна читалка статей і правила, які самі забирають нові серії, щойно вони з’являються.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Створено для клавіатури</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> відкриває палітру команд для всього: додати торрент, перейти на сторінку, увімкнути обмеження швидкості, перевірити оновлення…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Оновлюється сам</h3>
      Під час запуску Flux перевіряє релізи на GitHub. Одне клацання на <b>Оновити й перезапустити</b> — і він завантажує нову версію, звіряє її контрольну суму SHA-256, ставить на місце й знову відкривається.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Говорить вашою мовою</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski і 简体中文. Мова перемикається за секунду, без перезапуску, а числа й дати підлаштовуються під неї.
    </td>
  </tr>
</table>

І все, чого ви чекаєте від qBittorrent, на місці: послідовне завантаження й першочергове завантаження першої та останньої частин, категорії, обмеження швидкості за розкладом, черга, DHT / PeX / LSD, шифрування, проксі, UPnP / NAT-PMP, створення торрентів і повний набір розширених налаштувань libtorrent.

## 📸 Знімки екрана

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Пошук на трекерах"><p align="center"><sub>Пошук на трекерах</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Медіатека"><p align="center"><sub>Медіатека</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="RSS-стрічки"><p align="center"><sub>RSS-стрічки й читалка статей</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Налаштування мови"><p align="center"><sub>Дев’ять мов, перемикання на льоту</sub></p></td>
  </tr>
</table>

## 🚀 Початок роботи

Завантажте один із двох файлів з [останнього релізу](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest):

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** — *рекомендовано* | Інсталятор у фірмовому стилі Flux. Встановлює програму лише для вас, тож права адміністратора не потрібні; додає ярлики в меню «Пуск» і на робочий стіл, відкриває файли `.torrent` і magnet-посилання, а видалити Flux можна в розділі *Інстальовані програми*. Нові версії встановлюються поверх попередньої. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | Портативна версія. Розпакуйте її будь-куди — підійде й флешка — і запустіть `Flux.exe`. Налаштування й торренти зберігаються в її теці `profile`, і оновлюється вона теж сама. |

Під час першого запуску Flux запропонує **перенести ваші торренти й налаштування з qBittorrent**. Спершу закрийте qBittorrent, а потім натисніть *Перенести*. Хочете почати все наново? Оберіть *Почати з чистого аркуша*.

**Вимоги:** Windows 10 (1809 або новіша) чи Windows 11, 64-розрядна. Більше нічого встановлювати не треба: усе потрібне Flux має з собою.

## ⌨️ Гарячі клавіші

| Клавіші | Дія | | У плеєрі | Дія |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Палітра команд | | <kbd>Space</kbd> | Відтворення / пауза |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Додати торрент-файл | | <kbd>←</kbd> <kbd>→</kbd> | Перемотати назад / вперед |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Передачі, Пошук, RSS, Медіатека | | <kbd>↑</kbd> <kbd>↓</kbd> | Гучність |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Налаштування | | <kbd>M</kbd> | Вимкнути звук |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Згорнути меню | | <kbd>F</kbd> | На весь екран |
| | | | <kbd>Esc</kbd> | Вийти з плеєра |

## ❓ Часті запитання

<details>
<summary><b>Flux — це форк qBittorrent?</b></summary>
<br>
Так. Рушій — сесії, дані відновлення, трекери, сам протокол BitTorrent — це qBittorrent 5.2.4 на libtorrent 2.0.11. Flux замінює інтерфейс новим, написаним на Qt Quick (QML), і додає зверху стримінг, плеєр, медіатеку, пошук фільмів і оновлення.
</details>

<details>
<summary><b>Він не зіпсує мій qBittorrent?</b></summary>
<br>
Ні. Flux має власний профіль (<code>%APPDATA%\Flux</code> і <code>%LOCALAPPDATA%\Flux</code>). Перенесення <i>копіює</i> ваші торренти й налаштування qBittorrent, а оригінальний профіль лишається як був. Тільки не запускайте ті самі торренти в обох програмах одночасно.
</details>

<details>
<summary><b>Чому після «Запустити» торрент розганяється не одразу, а за кілька секунд?</b></summary>
<br>
Коли торрент зупиняють, його з’єднання закриваються. Після запуску Flux знову звертається до пірів, а коли почати віддавати дані — вирішують уже вони: більшість клієнтів переглядає це рішення кожні 10–15 секунд. Тим часом Flux показує <i>«Підключення до пірів…»</i>. qBittorrent поводиться точнісінько так само.
</details>

<details>
<summary><b>Windows називає інсталятор «нерозпізнаною програмою». Це безпечно?</b></summary>
<br>
SmartScreen попереджає про кожну нову програму, яка ще не має платного сертифіката для підпису коду, а Flux його не має. Натисніть <i>Докладніше</i> → <i>Усе одно запустити</i>. Щоб переконатися, що файл саме той, який опубліковано тут, порівняйте його SHA-256 із <code>SHA256SUMS.txt</code> у релізі (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> у PowerShell).
</details>

<details>
<summary><b>Як видалити Flux?</b></summary>
<br>
Відкрийте <i>Настройки → Програми → Інстальовані програми</i>, знайдіть <b>Flux Torrent</b> і виберіть <i>Видалити</i>. Деінсталятор запитає, чи зберегти ваші налаштування та список роздач; завантажених файлів він ніколи не торкається. Портативна версія — це просто тека: видаліть її.
</details>

<details>
<summary><b>Чи потрібен Python для пошуку?</b></summary>
<br>
Для вбудованого джерела фільмів і серіалів — ні. Python потрібен лише для класичних пошукових плагінів qBittorrent, так само як і в самому qBittorrent.
</details>

<details>
<summary><b>Чи є веб-інтерфейс, версія для Linux або macOS?</b></summary>
<br>
Поки що Flux працює лише на Windows. Веб-інтерфейс qBittorrent нікуди не подівся (типово вимкнений; його можна ввімкнути у файлі конфігурації).
</details>

<details>
<summary><b>Це законно?</b></summary>
<br>
BitTorrent — це технологія обміну файлами, якою щодня користуються для дистрибутивів Linux, ігор, відкритих фільмів і резервних копій. Flux — такий самий клієнт, як і будь-який інший. За те, що ви завантажуєте й роздаєте, відповідаєте ви самі, тож, будь ласка, дотримуйтеся законів своєї країни.
</details>

## 🛠 Збирання з вихідного коду

<details>
<summary><b>Показати кроки</b></summary>
<br>

Усе автоматизовано скриптами PowerShell. Перший скрипт встановлює інструменти (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg з OpenSSL, zlib, Boost 1.90 і libtorrent 2.0.11, libmpv) і фіксує їхні версії в <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Інструменти й залежності (один раз, у PowerShell з правами адміністратора)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Зібрати QML-інтерфейс і запустити тести
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Покласти готову до запуску копію разом із Qt і DLL у deploy\
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Реліз у dist\: інсталятор, портативний zip, контрольні суми й примітки до випуску
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Опублікуйте файли з <code>dist\</code> у релізі на GitHub із тегом <code>v&lt;version&gt;</code> (див. <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>) — і кожен Flux запропонує оновлення: встановлений візьме інсталятор, портативний — zip.

**Структура проєкту**

| Шлях | Що там лежить |
|---|---|
| `src/base`, `src/app` | Рушій і застосунок qBittorrent, якомога ближчі до upstream |
| `src/qmlgui/qml` | Інтерфейс: сторінки, елементи керування, плеєр |
| `src/qmlgui/backend` | Моделі C++, з якими працює інтерфейс (торренти, пошук, постери, RSS, оновлення, мови…) |
| `src/qmlgui/streaming` | Стримінг: планування випереджального читання й локальний сервер потоку |
| `src/qmlgui/i18n` | Переклади (`flux_<code>.ts`) |
| `src/installer` | Інсталятор: саморозпакувальний завантажувач без залежностей та інтерфейс встановлення на QML |
| `test/qmlgui` | Тести C++ і QML |

</details>

## 🌍 Переклади

Flux перекладено 9 мовами. Рядки лежать у [`src/qmlgui/i18n`](../../src/qmlgui/i18n) у вигляді файлів Qt `.ts`, по одному на мову, і відкриваються в Qt Linguist або будь-якому текстовому редакторі.

Помітили незграбну фразу або хочете додати свою мову? [Створіть issue](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) або надішліть pull request — у [`CONTRIBUTING.md`](../../CONTRIBUTING.md) описано, де що лежить, а перевірка в кожному pull request’і стежить, щоб кожен переклад був повним і зберігав усі заповнювачі.

## 🤝 Участь у розробці

Звіти про помилки, ідеї та pull request’и вітаються — подробиці в [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Перш ніж відкривати pull request, будь ласка, запустіть тести:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Подяки

Flux стоїть на плечах чудових проєктів з відкритим кодом:

- [qBittorrent](https://www.qbittorrent.org) — рушій і все, що робить його надійним
- [libtorrent](https://libtorrent.org) від Arvid Norberg — реалізація BitTorrent
- [Qt](https://www.qt.io) — фреймворк, на якому побудовано інтерфейс
- [mpv](https://mpv.io) — програвач, що стоїть за вбудованим плеєром
- [QWindowKit](https://github.com/stdware/qwindowkit) — вікно без рамки з нативним прилипанням до країв екрана
- [JacRed](https://jac.red) — джерело пошуку фільмів і серіалів
- Постери з [IMDb](https://www.imdb.com), [Wikipedia](https://www.wikipedia.org) і [Shikimori](https://shikimori.io)
- Шрифти [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) і [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); іконки в стилі [Lucide](https://lucide.dev)

## 📄 Ліцензія

Flux, як і qBittorrent, — вільне програмне забезпечення за ліцензією [GNU General Public License v2.0 або новішою](../../COPYING), з винятком для компонування з OpenSSL. Див. [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) і [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Зроблено з турботою для тих, хто просто хоче, щоб торренти працювали — і мали при цьому гарний вигляд.</sub></p>
