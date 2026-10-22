<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <b>Español</b> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.pl.md">Polski</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Logotipo de Flux Torrent">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Un cliente de torrents que de verdad da gusto mirar.</b><br>
  El núcleo a prueba de todo de qBittorrent, una interfaz completamente nueva y un reproductor que empieza la película mientras se descarga.
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><img src="https://img.shields.io/github/v/release/pinkmoneyx-bigguys/flux-torrent?style=flat-square&color=4f8cff&label=release" alt="Última versión"></a>
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases"><img src="https://img.shields.io/github/downloads/pinkmoneyx-bigguys/flux-torrent/total?style=flat-square&color=22c55e&label=downloads" alt="Descargas"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0a0a0a?style=flat-square&logo=windows11&logoColor=white" alt="Windows 10 y 11">
  <img src="https://img.shields.io/badge/core-qBittorrent%205.2.4-2f67ba?style=flat-square&logo=qbittorrent&logoColor=white" alt="Núcleo de qBittorrent 5.2.4">
  <img src="https://img.shields.io/badge/UI-Qt%206.10%20%2B%20QML-41cd52?style=flat-square&logo=qt&logoColor=white" alt="Qt 6.10">
  <img src="https://img.shields.io/badge/languages-9-ff7a59?style=flat-square" alt="9 idiomas">
  <a href="../../COPYING"><img src="https://img.shields.io/badge/license-GPL--2.0--or--later-blue?style=flat-square" alt="Licencia: GPL-2.0-or-later"></a>
</p>

<p align="center">
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Descargar para Windows</b></a>
  &nbsp;·&nbsp;
  <a href="https://pinkmoneyx-bigguys.github.io/flux-torrent/"><b>Sitio web</b></a>
  &nbsp;·&nbsp;
  <a href="#-funciones">Funciones</a>
  &nbsp;·&nbsp;
  <a href="#-capturas-de-pantalla">Capturas</a>
  &nbsp;·&nbsp;
  <a href="#-preguntas-frecuentes">Preguntas frecuentes</a>
  &nbsp;·&nbsp;
  <a href="#-compilar-desde-el-código-fuente">Compilar</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent: la pantalla Transferencias con un gráfico de velocidad en tiempo real" width="100%">
</p>

---

## 💡 Por qué Flux

qBittorrent es el motor de torrents de código abierto más fiable que existe, pero sigue pareciendo de 2010.
Flux deja ese motor **intacto** (qBittorrent 5.2.4 sobre libtorrent 2.0) y construye a su alrededor una aplicación moderna para Windows:

- 🎬 **Mira primero, descarga después.** Dale a reproducir en un torrent y la película empieza en segundos: Flux trae antes que nada las piezas que estás a punto de ver.
- 🔎 **Una búsqueda que entiende de cine.** Los resultados se agrupan por película, con pósteres, años y todos los torrents en una sola tarjeta.
- ✨ **Una interfaz tranquila y rápida.** Oscura, limpia y fluida, con gráficos en tiempo real y cifras que ruedan en lugar de parpadear.
- 🧳 **No pierdes nada.** Tus torrents y ajustes de qBittorrent se traen con un solo clic en el primer inicio.

## ✨ Funciones

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Reproductor integrado y streaming</h3>
      Reproduce un video mientras el torrent todavía se descarga. Flux pide primero las piezas que van justo por delante de la reproducción, muestra un indicador de búfer honesto y recuerda dónde te quedaste.
      <br><br>
      <b>Ver sin descargar</b> guarda la película en una caché temporal y la borra cuando terminas: nada se acumula en tu disco.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Búsqueda en trackers con pósteres</h3>
      Una fuente integrada de películas y series (JacRed) funciona desde el primer momento, sin necesidad de Python, junto a los clásicos plugins de búsqueda de qBittorrent.
      <br><br>
      Los resultados se convierten en <b>fichas de película</b>: pósteres de IMDb, Wikipedia y Shikimori, todos los torrents de una película en un mismo lugar, filtros «Con semillas» y «Con pósteres», y vista de lista o de cuadrícula.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Transferencias que te cuentan lo que pasa</h3>
      Filas de dos líneas con estados claros, un gráfico de velocidad en tiempo real para cada torrent, cifras de velocidad que ruedan, columnas redimensionables y un panel de detalles con piezas, archivos, trackers y pares.
      <br><br>
      Un torrent que acabas de iniciar dice <i>«Conectando con pares…»</i> en lugar de parecer atascado.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Mediateca</h3>
      Todos los videos de tus torrents, ordenados en películas y series con temporadas y episodios, etiquetas de calidad y progreso, listos para reproducir desde una sola pantalla.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS con descarga automática</h3>
      Canales y carpetas, un lector de artículos limpio y reglas que descargan los nuevos episodios por ti en cuanto aparecen.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Pensado para el teclado</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> abre una paleta de comandos para todo: añadir un torrent, saltar a una página, activar los límites de velocidad, buscar actualizaciones…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Se actualiza solo</h3>
      Flux consulta las versiones publicadas en GitHub al iniciarse. Un clic en <b>Actualizar y reiniciar</b> descarga la nueva versión, comprueba su suma SHA-256, la instala y vuelve a abrirla.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Habla tu idioma</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski y 简体中文. El cambio tarda un segundo, sin reiniciar, y los números y las fechas se adaptan al idioma.
    </td>
  </tr>
</table>

Y todo lo que esperas de qBittorrent sigue ahí: descarga secuencial y de la primera y la última pieza primero, categorías, límites de velocidad programados, la cola, DHT / PeX / LSD, cifrado, proxies, UPnP / NAT-PMP, creación de torrents y el conjunto completo de ajustes avanzados de libtorrent.

## 📸 Capturas de pantalla

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Búsqueda en trackers"><p align="center"><sub>Búsqueda en trackers</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Mediateca"><p align="center"><sub>Mediateca</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="Canales RSS"><p align="center"><sub>Canales RSS y el lector de artículos</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Ajustes de idioma"><p align="center"><sub>Nueve idiomas, con cambio al instante</sub></p></td>
  </tr>
</table>

## 🚀 Primeros pasos

Descarga uno de los dos archivos de la [última versión](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest):

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`** — *recomendado* | El instalador, con el aspecto propio de Flux. Se instala solo para ti, así que no hacen falta permisos de administrador; añade accesos directos en el menú Inicio y en el escritorio, abre los archivos `.torrent` y los enlaces magnet, y aparece en *Aplicaciones instaladas* para poder desinstalarlo. Las versiones nuevas se instalan sobre la anterior. |
| 🧳 **`Flux-<version>-portable-win64.zip`** | La versión portátil. Descomprímela donde quieras (sirve una memoria USB) y ejecuta `Flux.exe`. Los ajustes y los torrents se guardan en su carpeta `profile`, y también se actualiza sola. |

En el primer inicio, Flux te ofrece **traer tus torrents y ajustes de qBittorrent**. Cierra qBittorrent antes y pulsa *Migrar*. ¿Prefieres partir de cero? Elige *Empezar de cero*.

**Requisitos:** Windows 10 (1809 o posterior) o Windows 11, de 64 bits. No hay que instalar nada más: Flux trae todo lo que necesita.

## ⌨️ Atajos de teclado

| Atajo | Acción | | En el reproductor | Acción |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Paleta de comandos | | <kbd>Space</kbd> | Reproducir / pausa |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Añadir un archivo torrent | | <kbd>←</kbd> <kbd>→</kbd> | Retroceder / avanzar |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Transferencias, Búsqueda, RSS, Mediateca | | <kbd>↑</kbd> <kbd>↓</kbd> | Volumen |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Ajustes | | <kbd>M</kbd> | Silenciar |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Contraer la barra lateral | | <kbd>F</kbd> | Pantalla completa |
| | | | <kbd>Esc</kbd> | Salir del reproductor |

## ❓ Preguntas frecuentes

<details>
<summary><b>¿Flux es un fork de qBittorrent?</b></summary>
<br>
Sí. El motor (sesiones, datos de reanudación, trackers y el propio protocolo BitTorrent) es qBittorrent 5.2.4 sobre libtorrent 2.0.11. Flux sustituye la interfaz por una nueva escrita en Qt Quick (QML) y le añade el streaming, el reproductor, la mediateca, la búsqueda de películas y el actualizador.
</details>

<details>
<summary><b>¿Va a estropear mi qBittorrent?</b></summary>
<br>
No. Flux usa su propio perfil (<code>%APPDATA%\Flux</code> y <code>%LOCALAPPDATA%\Flux</code>). La migración <i>copia</i> tus torrents y ajustes de qBittorrent; el perfil original queda tal como estaba. Eso sí, no ejecutes los mismos torrents en las dos aplicaciones a la vez.
</details>

<details>
<summary><b>¿Por qué un torrent tarda unos segundos en ganar velocidad después de pulsar «Iniciar»?</b></summary>
<br>
Al detener un torrent se cierran sus conexiones. Al iniciarlo, Flux vuelve a contactar con los pares, y son ellos quienes deciden cuándo empezar a enviar: la mayoría de los clientes lo reconsideran cada 10–15 segundos. Mientras tanto, Flux muestra <i>«Conectando con pares…»</i>. qBittorrent se comporta exactamente igual.
</details>

<details>
<summary><b>Windows dice que el instalador es una aplicación «no reconocida». ¿Es seguro?</b></summary>
<br>
SmartScreen avisa de cada programa nuevo que aún no tiene un certificado de firma de código de pago, y Flux no lo tiene. Haz clic en <i>Más información</i> → <i>Ejecutar de todas formas</i>. Para asegurarte de que el archivo es el que se publicó aquí, compara su SHA-256 con <code>SHA256SUMS.txt</code> de la versión (<code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code> en PowerShell).
</details>

<details>
<summary><b>¿Cómo desinstalo Flux?</b></summary>
<br>
Abre <i>Configuración → Aplicaciones → Aplicaciones instaladas</i>, busca <b>Flux Torrent</b> y elige <i>Desinstalar</i>. El desinstalador pregunta si quieres conservar tus ajustes y la lista de torrents; los archivos descargados nunca se tocan. La versión portátil es solo una carpeta: bórrala.
</details>

<details>
<summary><b>¿Necesito Python para buscar?</b></summary>
<br>
No para la fuente integrada de películas y series. Python solo hace falta para los clásicos plugins de búsqueda de qBittorrent, igual que en qBittorrent.
</details>

<details>
<summary><b>¿Hay interfaz web o versión para Linux o macOS?</b></summary>
<br>
Por ahora Flux es solo para Windows. La interfaz web de qBittorrent sigue incluida (desactivada de forma predeterminada; se puede activar en el archivo de configuración).
</details>

<details>
<summary><b>¿Es legal?</b></summary>
<br>
BitTorrent es una tecnología para compartir archivos que se usa a diario para distribuciones de Linux, juegos, películas libres y copias de seguridad. Flux es un cliente como cualquier otro. Lo que descargas y compartes es responsabilidad tuya: respeta las leyes de tu país.
</details>

## 🛠 Compilar desde el código fuente

<details>
<summary><b>Ver los pasos</b></summary>
<br>

Todo está automatizado con scripts de PowerShell. El primer script instala las herramientas (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg con OpenSSL, zlib, Boost 1.90 y libtorrent 2.0.11, libmpv) y fija las versiones en <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Herramientas y dependencias (una sola vez, en un PowerShell con permisos de administrador)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Compilar la interfaz QML y ejecutar las pruebas
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Dejar en deploy\ una copia lista para ejecutar, con Qt y sus DLL
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Generar en dist\ una versión: el instalador, el zip portátil, las sumas de comprobación y las notas de la versión
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

Publica los archivos de <code>dist\</code> en una versión de GitHub con la etiqueta <code>v&lt;version&gt;</code> (consulta <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>) y todas las copias de Flux ofrecerán la actualización: las instaladas usan el instalador; las portátiles, el zip.

**Estructura del proyecto**

| Ruta | Qué contiene |
|---|---|
| `src/base`, `src/app` | El motor y la aplicación de qBittorrent, lo más cerca posible del original |
| `src/qmlgui/qml` | La interfaz: páginas, controles, el reproductor |
| `src/qmlgui/backend` | Modelos en C++ con los que habla la interfaz (torrents, búsqueda, pósteres, RSS, actualizaciones, idiomas…) |
| `src/qmlgui/streaming` | Streaming: planificación de la lectura anticipada y el servidor de streaming local |
| `src/qmlgui/i18n` | Traducciones (`flux_<code>.ts`) |
| `src/installer` | El instalador: un stub autoextraíble sin dependencias y su interfaz en QML |
| `test/qmlgui` | Pruebas de C++ y QML |

</details>

## 🌍 Traducciones

Flux está traducido a 9 idiomas. Los textos están en [`src/qmlgui/i18n`](../../src/qmlgui/i18n) como archivos `.ts` de Qt, uno por idioma, y se abren con Qt Linguist o con cualquier editor de texto.

¿Has visto una frase poco natural o quieres que se añada tu idioma? [Abre una incidencia](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) o envía un pull request: [`CONTRIBUTING.md`](../../CONTRIBUTING.md) explica dónde está cada cosa, y una comprobación en cada pull request se asegura de que cada traducción esté completa y conserve sus marcadores de posición.

## 🤝 Contribuir

Los informes de errores, las ideas y los pull requests son bienvenidos; encontrarás los detalles en [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Antes de abrir un pull request, ejecuta las pruebas:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Créditos

Flux se apoya en grandes proyectos de código abierto:

- [qBittorrent](https://www.qbittorrent.org): el motor y todo lo que lo hace fiable
- [libtorrent](https://libtorrent.org), de Arvid Norberg: la implementación de BitTorrent
- [Qt](https://www.qt.io): el framework con el que está hecha la interfaz
- [mpv](https://mpv.io): lo que hay detrás del reproductor integrado
- [QWindowKit](https://github.com/stdware/qwindowkit): la ventana sin marco con acoplamiento nativo
- [JacRed](https://jac.red): la fuente de búsqueda de películas y series
- Pósteres de [IMDb](https://www.imdb.com), [Wikipedia](https://www.wikipedia.org) y [Shikimori](https://shikimori.io)
- Fuentes [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) y [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); iconos al estilo de [Lucide](https://lucide.dev)

## 📄 Licencia

Flux, como qBittorrent, es software libre bajo la [GNU General Public License v2.0 o posterior](../../COPYING), con la excepción de enlace con OpenSSL. Consulta [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) y [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Hecho con cariño para quienes solo quieren que sus torrents funcionen… y que además se vean bien.</sub></p>
