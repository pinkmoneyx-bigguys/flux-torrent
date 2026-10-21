# Contributing to Flux

Thanks for wanting to help! Bug reports, ideas, translations and pull requests are all welcome.

## Reporting bugs and ideas

Use the [issue forms](https://github.com/pinkmoneyx-bigguys/flux-torrent/issues/new/choose): they ask for what helps
the most (the Flux version, how it is installed, your Windows version, the steps). English or Russian are both fine.

## Translations

Flux speaks English, Русский, Українська, Deutsch, Español, Français, Português (Brasil), Polski and 简体中文.

- The interface strings are in [`src/qmlgui/i18n`](src/qmlgui/i18n), one Qt `.ts` file per language (Qt Linguist
  or any text editor opens them). `flux_en.ts` only holds the English plural forms.
- The README is translated in [`docs/i18n`](docs/i18n), the installer's words in
  [`src/installer/ui/qml/Strings.js`](src/installer/ui/qml/Strings.js).
- `python scripts/check-translations.py` checks that every string is translated and keeps its placeholders
  (`%1`, `%n`…) — the same check runs on every pull request.

To add a language, add `i18n/flux_<code>.ts` to `TS_FILES` in [`src/qmlgui/CMakeLists.txt`](src/qmlgui/CMakeLists.txt)
and the code to `Languages::supported()` in [`src/qmlgui/backend/languages.cpp`](src/qmlgui/backend/languages.cpp),
then run `cmake --build build --target flux_lupdate` to create the file.

## Code

1. Set up the toolchain once: `powershell -ExecutionPolicy Bypass -File scripts/setup-env.ps1` (elevated).
2. Build and test: `powershell -ExecutionPolicy Bypass -File scripts/build.ps1 -Gui Qml -Test`.
3. Keep the style of the code around you — see [`CODING_GUIDELINES.md`](CODING_GUIDELINES.md) for C++. Changes to
   the qBittorrent engine (`src/base`, `src/app`) should stay small: they make merging upstream harder.
4. After changing UI strings, refresh the translation files with `cmake --build build --target flux_lupdate`.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org) (`feat(search): …`, `fix(transfers): …`).

## Releases

`powershell -ExecutionPolicy Bypass -File scripts/release.ps1` builds everything into `dist\`: the installer, the
portable archive, checksums and release notes (from [`CHANGELOG.md`](CHANGELOG.md)). Publish them in a GitHub release
tagged `v<version>` (the version is `FLUX_VERSION` in [`src/CMakeLists.txt`](src/CMakeLists.txt)) and every Flux out
there offers the update.
