<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.pl.md">Polski</a> ·
  <b>简体中文</b>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Flux Torrent 标志">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>一款让你真心愿意多看两眼的 Torrent 客户端。</b><br>
  qBittorrent 坚如磐石的内核、焕然一新的界面，再加上一个边下边播的播放器。
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
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ 下载 Windows 版</b></a>
  &nbsp;·&nbsp;
  <a href="https://pinkmoneyx-bigguys.github.io/flux-torrent/"><b>官网</b></a>
  &nbsp;·&nbsp;
  <a href="#-功能">功能</a>
  &nbsp;·&nbsp;
  <a href="#-截图">截图</a>
  &nbsp;·&nbsp;
  <a href="#-常见问题">常见问题</a>
  &nbsp;·&nbsp;
  <a href="#-从源码构建">构建</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent：带实时速度图的“传输”页面" width="100%">
</p>

---

## 💡 为什么选择 Flux

qBittorrent 是目前最可靠的开源 Torrent 引擎——可它的样子还停留在 2010 年。
Flux 对这个引擎**原封不动**（基于 libtorrent 2.0 的 qBittorrent 5.2.4），并围绕它打造了一款现代的 Windows 应用：

- 🎬 **先看，后下**。在 Torrent 上点击播放，几秒钟后电影就开始了——Flux 会先获取你马上要看到的区块，其余部分稍后再下。
- 🔎 **懂电影的搜索**。结果按影片归类，海报、年份和所有发布版本都汇集在一张卡片里。
- ✨ **安静、快速的界面**。深色、简洁、流畅，配有实时图表，数字平滑滚动而不是闪烁跳变。
- 🧳 **什么都不会丢**。首次启动时，一键即可把 qBittorrent 中的 Torrent 和设置迁移过来。

## ✨ 功能

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 内置播放器与流媒体</h3>
      Torrent 还在下载时就能播放视频。Flux 会优先请求播放位置前方的区块，如实显示缓冲进度，并记住你上次看到哪里。
      <br><br>
      <b>免下载观看</b>会把影片放在临时缓存中，看完即清理——不会在磁盘上越堆越多。
    </td>
    <td width="50%" valign="top">
      <h3>🔎 带海报的 Tracker 搜索</h3>
      内置的影视来源（JacRed）开箱即用——无需 Python——与经典的 qBittorrent 搜索插件并存。
      <br><br>
      搜索结果会变成<b>影片卡片</b>：海报来自 IMDb、Wikipedia 和 Shikimori，同一部影片的所有发布版本集中在一处，还有“有做种”和“有海报”筛选开关，可在列表和网格视图之间切换。
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 一目了然的传输列表</h3>
      双行条目、清晰的状态、每个 Torrent 的实时速度图、平滑滚动的速度数字、可调宽度的列，以及展示区块、文件、Tracker 和用户的详情面板。
      <br><br>
      刚开始的 Torrent 会显示<i>“正在连接用户…”</i>，而不是看起来像卡住了。
    </td>
    <td width="50%" valign="top">
      <h3>📚 媒体库</h3>
      Torrent 中的每个视频都会被整理为电影和剧集，按季和集排列，附带画质标签和进度——在同一个页面即可直接播放。
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 支持自动下载的 RSS</h3>
      订阅源和文件夹、简洁的文章阅读器，还有规则会在新剧集一出现时就替你下载。
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ 为键盘而生</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> 打开命令面板，一切操作尽在其中：添加 Torrent、跳转到页面、切换速度限制、检查更新…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 自动更新</h3>
      Flux 启动时会检查 GitHub 上的发布版本。只需点击<b>更新并重启</b>，它就会下载新版本、校验 SHA-256 校验和、完成替换并重新打开。
    </td>
    <td width="50%" valign="top">
      <h3>🌍 说你的语言</h3>
      English、Русский、Українська、Deutsch、Español、Français、Português (Brasil)、Polski 和简体中文。切换只需一秒，无需重启，数字和日期格式也会随语言改变。
    </td>
  </tr>
</table>

当然，你在 qBittorrent 中熟悉的一切依然都在：顺序下载与优先下载首尾区块、分类、可按计划生效的速度限制、队列、DHT / PeX / LSD、加密、代理、UPnP / NAT-PMP、创建 Torrent，以及全套 libtorrent 高级设置。

## 📸 截图

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Tracker 搜索"><p align="center"><sub>Tracker 搜索</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="媒体库"><p align="center"><sub>媒体库</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="RSS 订阅"><p align="center"><sub>RSS 订阅与文章阅读器</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="语言设置"><p align="center"><sub>九种语言，即时切换</sub></p></td>
  </tr>
</table>

## 🚀 快速上手

从[最新发布版](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest)中任选其一下载：

| | |
|---|---|
| 📦 **`Flux-<version>-setup.exe`**（*推荐*） | 安装程序，采用 Flux 自己的界面风格。仅为你安装，因此无需管理员权限；会创建“开始”菜单和桌面快捷方式，用 Flux 打开 `.torrent` 文件和磁力链接，并出现在 *已安装的应用* 中，方便卸载。新版本会直接覆盖安装。 |
| 🧳 **`Flux-<version>-portable-win64.zip`** | 便携版。解压到任意位置（U 盘也可以），然后运行 `Flux.exe`。设置和 Torrent 都保存在它的 `profile` 文件夹中，它同样会自动更新。 |

首次启动时，Flux 会提出**从 qBittorrent 迁移你的 Torrent 和设置**。请先关闭 qBittorrent，然后点击 *迁移*。想从零开始？选择 *全新开始* 即可。

**系统要求**：Windows 10（1809 或更高版本）或 Windows 11，64 位。无需另外安装任何东西：Flux 自带所需的一切。

## ⌨️ 快捷键

| 快捷键 | 操作 | | 播放器中 | 操作 |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | 命令面板 | | <kbd>Space</kbd> | 播放 / 暂停 |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | 添加 Torrent 文件 | | <kbd>←</kbd> <kbd>→</kbd> | 后退 / 快进 |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | 传输、搜索、RSS、媒体库 | | <kbd>↑</kbd> <kbd>↓</kbd> | 音量 |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | 设置 | | <kbd>M</kbd> | 静音 |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | 收起侧边栏 | | <kbd>F</kbd> | 全屏 |
| | | | <kbd>Esc</kbd> | 退出播放器 |

## ❓ 常见问题

<details>
<summary><b>Flux 是 qBittorrent 的分支吗？</b></summary>
<br>
是的。引擎部分——会话、恢复数据、Tracker，乃至 BitTorrent 协议本身——都是基于 libtorrent 2.0.11 的 qBittorrent 5.2.4。Flux 用 Qt Quick（QML）编写的全新界面取代了原来的界面，并在此之上加入了流媒体播放、播放器、媒体库、影视搜索和自动更新。
</details>

<details>
<summary><b>它会弄乱我的 qBittorrent 吗？</b></summary>
<br>
不会。Flux 使用自己独立的配置（<code>%APPDATA%\Flux</code> 和 <code>%LOCALAPPDATA%\Flux</code>）。迁移只会<i>复制</i>你在 qBittorrent 中的 Torrent 和设置，原配置保持不变。只是请不要在两个应用中同时运行相同的 Torrent。
</details>

<details>
<summary><b>为什么点击“开始”后，Torrent 要过几秒才会提速？</b></summary>
<br>
停止 Torrent 会关闭它的所有连接。重新开始后，Flux 会再次连接用户，而何时开始发送数据由对方决定——大多数客户端每 10–15 秒才重新评估一次。在此期间，Flux 会显示<i>“正在连接用户…”</i>。qBittorrent 的表现也完全一样。
</details>

<details>
<summary><b>Windows 提示安装程序是“无法识别的应用”，它安全吗？</b></summary>
<br>
对于每个还没有付费代码签名证书的新程序，SmartScreen 都会发出警告，而 Flux 目前没有这种证书。点击<i>更多信息</i> → <i>仍要运行</i>。若要确认文件正是这里发布的那一个，请将它的 SHA-256 与发布版中的 <code>SHA256SUMS.txt</code> 进行比对（在 PowerShell 中运行 <code>Get-FileHash Flux-&lt;version&gt;-setup.exe</code>）。
</details>

<details>
<summary><b>如何卸载 Flux？</b></summary>
<br>
打开<i>设置 → 应用 → 已安装的应用</i>，找到 <b>Flux Torrent</b> 并选择<i>卸载</i>。卸载程序会询问是否保留你的设置和 Torrent 列表；已下载的文件绝不会被改动。便携版只是一个文件夹：直接删除即可。
</details>

<details>
<summary><b>搜索需要 Python 吗？</b></summary>
<br>
内置的影视来源不需要。只有经典的 qBittorrent 搜索插件才需要 Python，这一点和 qBittorrent 相同。
</details>

<details>
<summary><b>有 Web UI、Linux 版或 macOS 版吗？</b></summary>
<br>
Flux 目前仅支持 Windows。qBittorrent 的 Web UI 依然内置其中（默认关闭，可在配置文件中开启）。
</details>

<details>
<summary><b>这合法吗？</b></summary>
<br>
BitTorrent 是一种文件分享技术，每天都被用来分发 Linux 发行版、游戏、开放版权的电影和备份。Flux 和其他客户端一样，只是一个客户端。下载和分享什么由你自己负责——请遵守你所在国家或地区的法律。
</details>

## 🛠 从源码构建

<details>
<summary><b>展开步骤</b></summary>
<br>

所有步骤都已写成 PowerShell 脚本。第一个脚本会安装工具链（Visual Studio 2022 Build Tools、Python 3.13、CMake、Ninja、Qt 6.10.1、包含 OpenSSL、zlib、Boost 1.90 和 libtorrent 2.0.11 的 vcpkg，以及 libmpv），并把版本锁定在 <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a> 中。

```powershell
# 1. 工具链和依赖（只需运行一次，在以管理员身份运行的 PowerShell 中）
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. 构建 QML 界面并运行测试
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. 在 deploy\ 中生成可直接运行的副本，附带所需的 Qt 和 DLL
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. 在 dist\ 中生成发布文件：安装程序、便携版 zip、校验和以及发布说明
powershell -ExecutionPolicy Bypass -File scripts/release.ps1
```

将 <code>dist\</code> 中的文件发布到标签为 <code>v&lt;version&gt;</code> 的 GitHub 发布版中（参见 <a href="../../CHANGELOG.md"><code>CHANGELOG.md</code></a>），所有在用的 Flux 都会提示更新：安装版获取安装程序，便携版获取 zip。

**项目结构**

| 路径 | 内容 |
|---|---|
| `src/base`、`src/app` | qBittorrent 的引擎和应用程序，尽量与上游保持一致 |
| `src/qmlgui/qml` | 界面：页面、控件、播放器 |
| `src/qmlgui/backend` | 供界面调用的 C++ 模型（Torrent、搜索、海报、RSS、更新、语言…） |
| `src/qmlgui/streaming` | 流媒体：预读规划和本地流媒体服务器 |
| `src/qmlgui/i18n` | 翻译文件（`flux_<code>.ts`） |
| `src/installer` | 安装程序：无依赖的自解压存根及其 QML 界面 |
| `test/qmlgui` | C++ 和 QML 测试 |

</details>

## 🌍 翻译

Flux 已被翻译成 9 种语言。字符串以 Qt `.ts` 文件的形式存放在 [`src/qmlgui/i18n`](../../src/qmlgui/i18n) 中，每种语言一个文件，可以用 Qt Linguist 或任意文本编辑器打开。

发现了别扭的措辞，或者希望加入你的语言？欢迎[提交 Issue](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) 或发送 Pull Request——[`CONTRIBUTING.md`](../../CONTRIBUTING.md) 介绍了各部分的位置，每个 Pull Request 上的检查都会确认每份翻译是否完整、占位符是否保留。

## 🤝 参与贡献

欢迎提交 Bug 报告、想法和 Pull Request，详情见 [`CONTRIBUTING.md`](../../CONTRIBUTING.md)。提交 Pull Request 之前，请先运行测试：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 致谢

Flux 站在众多优秀开源项目的肩膀上：

- [qBittorrent](https://www.qbittorrent.org)——引擎，以及让它稳定可靠的一切
- [libtorrent](https://libtorrent.org)，作者 Arvid Norberg——BitTorrent 协议的实现
- [Qt](https://www.qt.io)——构建界面所用的框架
- [mpv](https://mpv.io)——内置播放器背后的播放引擎
- [QWindowKit](https://github.com/stdware/qwindowkit)——支持原生窗口贴靠的无边框窗口
- [JacRed](https://jac.red)——影视搜索来源
- 海报来自 [IMDb](https://www.imdb.com)、[Wikipedia](https://www.wikipedia.org) 和 [Shikimori](https://shikimori.io)
- 字体 [Geist](https://fonts.google.com/specimen/Geist)、[Onest](https://fonts.google.com/specimen/Onest)、[Unbounded](https://fonts.google.com/specimen/Unbounded) 和 [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono)；图标采用 [Lucide](https://lucide.dev) 风格

## 📄 许可证

Flux 与 qBittorrent 一样，是遵循 [GNU 通用公共许可证 v2.0 或更高版本](../../COPYING)的自由软件，并附带 OpenSSL 链接例外。详见 [`COPYING`](../../COPYING)、[`COPYING.GPLv2`](../../COPYING.GPLv2) 和 [`COPYING.GPLv3`](../../COPYING.GPLv3)。

<p align="center"><sub>用心打造，献给只想让 Torrent 好好工作——顺便好看一点——的每一个人。</sub></p>
