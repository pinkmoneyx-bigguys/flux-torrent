<!-- Language switcher: keep in sync with docs/i18n/README.*.md -->
<p align="center">
  <a href="../../README.md">English</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.uk.md">Українська</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.fr.md">Français</a> ·
  <b>Português</b> ·
  <a href="README.pl.md">Polski</a> ·
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="../assets/logo.svg" width="96" height="96" alt="Logo do Flux Torrent">
</p>

<h1 align="center">Flux Torrent</h1>

<p align="center">
  <b>Um cliente de torrent que dá gosto de ver.</b><br>
  O núcleo sólido do qBittorrent, uma interface totalmente nova e um player que começa o filme enquanto ele ainda está baixando.
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
  <a href="https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest"><b>⬇ Baixar para Windows</b></a>
  &nbsp;·&nbsp;
  <a href="#-recursos">Recursos</a>
  &nbsp;·&nbsp;
  <a href="#-capturas-de-tela">Capturas de tela</a>
  &nbsp;·&nbsp;
  <a href="#-perguntas-frequentes">Perguntas frequentes</a>
  &nbsp;·&nbsp;
  <a href="#-compilar-a-partir-do-código-fonte">Compilação</a>
</p>

<p align="center">
  <img src="../assets/hero.png" alt="Flux Torrent: a tela Transferências com um gráfico de velocidade ao vivo" width="100%">
</p>

---

## 💡 Por que o Flux

O qBittorrent é o motor de torrent de código aberto mais confiável que existe — e ainda tem cara de 2010.
O Flux mantém esse motor **intacto** (qBittorrent 5.2.4 sobre libtorrent 2.0) e constrói em volta dele um aplicativo moderno para Windows:

- 🎬 **Assista primeiro, baixe depois.** Dê play em um torrent e o filme começa em segundos — o Flux busca os pedaços que você vai ver logo antes de todo o resto.
- 🔎 **Uma busca que entende de filmes.** Os resultados são agrupados por filme, com pôster, ano e todos os lançamentos em um único card.
- ✨ **Uma interface tranquila e rápida.** Escura, limpa e fluida, com gráficos ao vivo e números que rolam em vez de piscar.
- 🧳 **Nada se perde.** Seus torrents e configurações do qBittorrent vêm junto com um clique na primeira execução.

## ✨ Recursos

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎬 Player e streaming integrados</h3>
      Assista a um vídeo enquanto o torrent ainda está baixando. O Flux pede primeiro os pedaços logo à frente do ponto de reprodução, mostra um indicador de buffer honesto e lembra onde você parou.
      <br><br>
      <b>Assistir sem baixar</b> guarda o filme em um cache temporário e o apaga quando você termina — nada se acumula no seu disco.
    </td>
    <td width="50%" valign="top">
      <h3>🔎 Busca nos rastreadores com pôsteres</h3>
      Uma fonte de filmes e séries integrada (JacRed) funciona logo de cara — sem precisar de Python — ao lado dos clássicos plugins de busca do qBittorrent.
      <br><br>
      Os resultados viram <b>cards de filmes</b>: pôsteres encontrados no IMDb, na Wikipedia e no Shikimori, todos os lançamentos de um filme em um só lugar, filtros “Com sementes” e “Com pôsteres”, em lista ou em grade.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📊 Transferências que mostram o que está acontecendo</h3>
      Linhas em dois níveis com status claros, um gráfico de velocidade ao vivo para cada torrent, números de velocidade que rolam, colunas redimensionáveis e um painel de detalhes com pedaços, arquivos, rastreadores e pares.
      <br><br>
      Um torrent que você acabou de iniciar mostra <i>“Conectando aos pares…”</i> em vez de parecer travado.
    </td>
    <td width="50%" valign="top">
      <h3>📚 Biblioteca de mídia</h3>
      Todos os vídeos dos seus torrents, organizados em filmes e séries com temporadas e episódios, selos de qualidade e progresso — prontos para assistir a partir de uma única tela.
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>📰 RSS com download automático</h3>
      Feeds e pastas, um leitor de artigos limpo e regras que baixam os novos episódios para você assim que eles saem.
    </td>
    <td width="50%" valign="top">
      <h3>⌨️ Feito para o teclado</h3>
      <kbd>Ctrl</kbd> + <kbd>K</kbd> abre uma paleta de comandos para tudo: adicionar um torrent, ir para uma página, ligar ou desligar os limites de velocidade, verificar atualizações…
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h3>🔄 Atualiza sozinho</h3>
      Ao abrir, o Flux confere os lançamentos no GitHub. Um clique em <b>Atualizar e reiniciar</b> baixa a nova versão, verifica o checksum SHA-256, instala e abre o aplicativo de novo.
    </td>
    <td width="50%" valign="top">
      <h3>🌍 Fala o seu idioma</h3>
      English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski e 简体中文. A troca leva um segundo — sem reiniciar — e números e datas acompanham o idioma.
    </td>
  </tr>
</table>

E tudo o que você espera do qBittorrent continua lá: download em sequência e dos primeiros e últimos pedaços antes, categorias, limites de velocidade com agendamento, fila, DHT / PeX / LSD, criptografia, proxies, UPnP / NAT-PMP, criação de torrents e o conjunto completo de configurações avançadas do libtorrent.

## 📸 Capturas de tela

<table>
  <tr>
    <td width="50%"><img src="../assets/search.png" alt="Busca nos rastreadores"><p align="center"><sub>Busca nos rastreadores</sub></p></td>
    <td width="50%"><img src="../assets/library.png" alt="Biblioteca de mídia"><p align="center"><sub>Biblioteca de mídia</sub></p></td>
  </tr>
  <tr>
    <td width="50%"><img src="../assets/rss.png" alt="Feeds RSS"><p align="center"><sub>Feeds RSS e o leitor de artigos</sub></p></td>
    <td width="50%"><img src="../assets/languages.png" alt="Configurações de idioma"><p align="center"><sub>Nove idiomas, trocados na hora</sub></p></td>
  </tr>
</table>

## 🚀 Primeiros passos

1. Baixe o **`Flux-<version>-win64.zip`** do [lançamento mais recente](https://github.com/pinkmoneyx-bigguys/flux-torrent/releases/latest).
2. Descompacte onde quiser — por exemplo, em `C:\Program Files\Flux` ou em uma pasta do seu perfil de usuário.
3. Execute o **`Flux.exe`**.

Na primeira execução, o Flux oferece **trazer seus torrents e configurações do qBittorrent**. Feche o qBittorrent antes e depois clique em *Migrar*. Prefere começar do jeito limpo? Escolha *Começar do zero*.

> [!TIP]
> **Modo portátil:** crie uma pasta vazia chamada `profile` ao lado do `Flux.exe`, e o Flux guarda ali todas as configurações e torrents — prático para um pendrive.

**Requisitos:** Windows 10 (1809 ou mais recente) ou Windows 11, 64 bits.

## ⌨️ Atalhos de teclado

| Atalho | Ação | | No player | Ação |
|---|---|---|---|---|
| <kbd>Ctrl</kbd> <kbd>K</kbd> | Paleta de comandos | | <kbd>Space</kbd> | Reproduzir / pausar |
| <kbd>Ctrl</kbd> <kbd>O</kbd> | Adicionar um arquivo torrent | | <kbd>←</kbd> <kbd>→</kbd> | Voltar / avançar |
| <kbd>Ctrl</kbd> <kbd>1</kbd>…<kbd>4</kbd> | Transferências, Busca, RSS, Biblioteca | | <kbd>↑</kbd> <kbd>↓</kbd> | Volume |
| <kbd>Ctrl</kbd> <kbd>,</kbd> | Configurações | | <kbd>M</kbd> | Silenciar |
| <kbd>Ctrl</kbd> <kbd>B</kbd> | Recolher a barra lateral | | <kbd>F</kbd> | Tela cheia |
| | | | <kbd>Esc</kbd> | Sair do player |

## ❓ Perguntas frequentes

<details>
<summary><b>O Flux é um fork do qBittorrent?</b></summary>
<br>
Sim. O motor — sessões, dados de retomada, rastreadores, o próprio protocolo BitTorrent — é o qBittorrent 5.2.4 sobre libtorrent 2.0.11. O Flux troca a interface por uma nova, escrita em Qt Quick (QML), e acrescenta o streaming, o player, a biblioteca de mídia, a busca de filmes e o atualizador.
</details>

<details>
<summary><b>Ele vai bagunçar o meu qBittorrent?</b></summary>
<br>
Não. O Flux tem o próprio perfil (<code>%APPDATA%\Flux</code> e <code>%LOCALAPPDATA%\Flux</code>). A migração <i>copia</i> seus torrents e configurações do qBittorrent; o perfil original fica como estava. Só não rode os mesmos torrents nos dois aplicativos ao mesmo tempo.
</details>

<details>
<summary><b>Por que um torrent leva alguns segundos para ganhar velocidade depois de “Iniciar”?</b></summary>
<br>
Parar um torrent fecha as conexões dele. Ao iniciar de novo, o Flux volta a procurar os pares, e cabe a eles decidir quando começar a enviar — a maioria dos clientes reavalia isso a cada 10–15 segundos. Enquanto isso, o Flux mostra <i>“Conectando aos pares…”</i>. O qBittorrent se comporta exatamente da mesma forma.
</details>

<details>
<summary><b>Preciso de Python para a busca?</b></summary>
<br>
Não para a fonte de filmes e séries integrada. O Python só é necessário para os clássicos plugins de busca do qBittorrent, assim como no próprio qBittorrent.
</details>

<details>
<summary><b>Existe uma Web UI ou uma versão para Linux ou macOS?</b></summary>
<br>
Por enquanto, o Flux é só para Windows. A Web UI do qBittorrent continua embutida (desativada por padrão; dá para ativá-la no arquivo de configuração).
</details>

<details>
<summary><b>Isso é legal?</b></summary>
<br>
O BitTorrent é uma tecnologia de compartilhamento de arquivos, usada todos os dias para distribuições Linux, jogos, filmes abertos e backups. O Flux é um cliente como qualquer outro. O que você baixa e compartilha é responsabilidade sua — respeite as leis do seu país.
</details>

## 🛠 Compilar a partir do código-fonte

<details>
<summary><b>Mostrar as etapas</b></summary>
<br>

Tudo é automatizado em PowerShell. O primeiro script instala as ferramentas (Visual Studio 2022 Build Tools, Python 3.13, CMake, Ninja, Qt 6.10.1, vcpkg com OpenSSL, zlib, Boost 1.90 e libtorrent 2.0.11, libmpv) e fixa as versões em <a href="../../scripts/deps.lock"><code>scripts/deps.lock</code></a>.

```powershell
# 1. Ferramentas e dependências (execute uma vez, em um PowerShell como administrador)
powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1

# 2. Compile a interface QML e rode os testes
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test

# 3. Coloque uma cópia executável, com o Qt e as DLLs, em deploy\
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Deploy

# 4. Empacote deploy\ em dist\Flux-<version>-win64.zip para um lançamento
powershell -ExecutionPolicy Bypass -File scripts/package.ps1
```

Basta publicar no GitHub um lançamento com a tag <code>v&lt;version&gt;</code> e esse zip anexado para que todo Flux instalado ofereça a atualização.

**Estrutura do projeto**

| Caminho | O que tem lá |
|---|---|
| `src/base`, `src/app` | O motor e o aplicativo do qBittorrent, mantidos próximos do upstream |
| `src/qmlgui/qml` | A interface: páginas, controles, o player |
| `src/qmlgui/backend` | Modelos em C++ com que a interface conversa (torrents, busca, pôsteres, RSS, atualizações, idiomas…) |
| `src/qmlgui/streaming` | Streaming: planejamento da leitura antecipada e o servidor de stream local |
| `src/qmlgui/i18n` | Traduções (`flux_<code>.ts`) |
| `test/qmlgui` | Testes em C++ e QML |

</details>

## 🌍 Traduções

O Flux está traduzido para 9 idiomas. Os textos ficam em [`src/qmlgui/i18n`](../../src/qmlgui/i18n) como arquivos `.ts` do Qt, um por idioma, e abrem no Qt Linguist ou em qualquer editor de texto.

Achou alguma frase estranha ou quer ver o seu idioma aqui? [Abra uma issue](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues) ou envie um pull request — um teste confere se cada tradução está completa e mantém os seus marcadores.

## 🤝 Como contribuir

Relatos de bugs, ideias e pull requests são bem-vindos. Antes de abrir um pull request, rode os testes:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test
```

## 🙏 Créditos

O Flux se apoia nos ombros de grandes projetos de código aberto:

- [qBittorrent](https://www.qbittorrent.org) — o motor e tudo o que o torna confiável
- [libtorrent](https://libtorrent.org), de Arvid Norberg — a implementação do BitTorrent
- [Qt](https://www.qt.io) — o framework em que a interface é construída
- [mpv](https://mpv.io) — o que está por trás do player integrado
- [QWindowKit](https://github.com/stdware/qwindowkit) — a janela sem moldura com encaixe nativo
- [JacRed](https://jac.red) — a fonte de busca de filmes e séries
- Pôsteres do [IMDb](https://www.imdb.com), da [Wikipedia](https://www.wikipedia.org) e do [Shikimori](https://shikimori.io)
- Fontes [Geist](https://fonts.google.com/specimen/Geist), [Onest](https://fonts.google.com/specimen/Onest), [Unbounded](https://fonts.google.com/specimen/Unbounded) e [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono); ícones no estilo do [Lucide](https://lucide.dev)

## 📄 Licença

O Flux, assim como o qBittorrent, é software livre sob a [GNU General Public License v2.0 ou posterior](../../COPYING), com a exceção de vinculação ao OpenSSL. Veja [`COPYING`](../../COPYING), [`COPYING.GPLv2`](../../COPYING.GPLv2) e [`COPYING.GPLv3`](../../COPYING.GPLv3).

<p align="center"><sub>Feito com carinho para quem só quer que os torrents funcionem — e com boa aparência.</sub></p>
