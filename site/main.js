// Flux Torrent's site: English or Russian (the browser's choice, then the visitor's), and the download buttons
// pointed at the latest release's files with their sizes.
(() => {
  const repo = "pinkmoneyx-bigguys/flux-torrent";

  const ru = {
    "nav.features": "Возможности",
    "nav.download": "Скачать",
    "nav.faq": "Вопросы",
    "hero.lead": "Торрент-клиент для Windows, который начинает показывать фильм, пока тот ещё качается. Поиск по трекерам с постерами, медиатека и RSS на движке qBittorrent.",
    "hero.download": "Скачать для Windows",
    "hero.portable": "Портативная версия",
    "hero.fine": "Windows 10 и 11, 64 бит. Бесплатно, с открытым кодом.",
    "alt.transfers": "Flux Torrent: передачи с живым графиком скорости",
    "f.search.title": "Ищите на трекерах, а видите фильмы",
    "f.search.text": "Результаты собираются в карточки фильмов с постерами. В карточке каждая раздача целиком: качество, HDR, источник и озвучки, описание из Википедии на вашем языке и трейлер. Остаются только фильмы, в названиях которых есть ваши слова.",
    "alt.search": "Поиск по трекерам: сетка постеров",
    "alt.film": "Карточка фильма с раздачами",
    "f.library.title": "Всё скачанное на одной полке",
    "f.library.text": "Медиатека находит каждое видео в ваших торрентах: один постер на фильм или сериал. Фильм играет прямо с постера, а сериал открывает серии по сезонам: что вы уже посмотрели и что ещё качается.",
    "alt.library": "Медиатека: полка постеров",
    "alt.series": "Сериал со списком серий",
    "f.rss.title": "Новые серии приходят сами",
    "f.rss.text": "Подпишитесь на RSS-ленту трекера или сериала и читайте её во Flux. Правила автозагрузки скачают новую серию в нужном качестве, как только она выйдет.",
    "alt.rss": "RSS-ленты и читалка статей",
    "x.watch.t": "Смотрите, пока качается",
    "x.watch.d": "Встроенный плеер первыми просит куски прямо перед курсором. «Смотреть без скачивания» держит фильм во временном кэше и потом убирает его.",
    "x.engine.t": "Движок qBittorrent",
    "x.engine.d": "Внутри qBittorrent 5.2 и libtorrent 2.0: те же загрузки, ограничения, очереди и трекеры, в новом интерфейсе.",
    "x.move.t": "Переезд с qBittorrent",
    "x.move.d": "При первом запуске Flux переносит ваши раздачи и настройки в один клик.",
    "x.lang.t": "Девять языков",
    "x.lang.d": "English, Русский, Українська, Deutsch, Español, Français, Português, Polski и 简体中文, переключаются на лету.",
    "x.update.t": "Обновляется сам",
    "x.update.d": "Новая версия ставится в один клик, а перед установкой сверяется по SHA-256.",
    "x.tray.t": "Работает из трея",
    "x.tray.d": "Закройте окно, и Flux продолжит качать и раздавать, а скорости будут видны у часов.",
    "d.title": "Скачать Flux",
    "d.setup.title": "Установщик",
    "d.setup.text": "Ставится только для вас, права администратора не нужны. Ярлыки в «Пуске» и на рабочем столе, файлы .torrent и magnet-ссылки, обновления поверх. Удаляется через «Установленные приложения».",
    "d.setup.button": "Скачать установщик",
    "d.portable.title": "Портативная",
    "d.portable.text": "Распакуйте куда угодно, хоть на флешку, и запустите Flux.exe. Настройки и раздачи хранятся в её папке profile, и обновляется она тоже сама.",
    "d.portable.button": "Скачать zip",
    "d.all": "Все версии и их контрольные суммы — на <a href=\"https://github.com/pinkmoneyx-bigguys/flux-torrent/releases\">странице релизов</a>.",
    "q.title": "Вопросы",
    "q.smart.q": "Windows называет установщик «неопознанным приложением». Это безопасно?",
    "q.smart.a": "SmartScreen предупреждает о любой новой программе без платного сертификата подписи кода, а у Flux его пока нет. Нажмите «Подробнее», затем «Выполнить в любом случае». Чтобы убедиться, что файл тот самый, сравните его SHA-256 с SHA256SUMS.txt из релиза.",
    "q.qbt.q": "Чем он отличается от qBittorrent?",
    "q.qbt.a": "Движок тот же, интерфейс новый: плеер, который играет во время загрузки, поиск с постерами и карточками фильмов, медиатека и собственный облик. Настройки и раздачи qBittorrent переезжают при первом запуске.",
    "q.remove.q": "Как удалить Flux?",
    "q.remove.a": "Откройте «Параметры → Приложения → Установленные приложения», найдите Flux Torrent и выберите «Удалить». Он спросит, сохранить ли настройки и список раздач, а скачанные файлы не трогает никогда. Портативная версия — просто папка: удалите её.",
    "q.bug.q": "Что-то не работает. Куда написать?",
    "q.bug.a": "Откройте <a href=\"https://github.com/pinkmoneyx-bigguys/flux-torrent/issues/new/choose\">issue на GitHub</a>: форма спросит версию Flux и шаги. Можно по-русски.",
    "foot.text": "Сделано на <a href=\"https://www.qbittorrent.org\">qBittorrent</a> и <a href=\"https://libtorrent.org\">libtorrent</a>. Лицензия GPL.",
    "release.line": "Версия {v}. Windows 10 и 11, 64 бит. Бесплатно, с открытым кодом.",
    "size": "Версия {v}, {s}",
    "units": ["Б", "КБ", "МБ", "ГБ"]
  };

  // the English is in the page: read it once, to come back to
  const en = {};
  document.querySelectorAll("[data-i18n]").forEach(el => en[el.dataset.i18n] = el.textContent);
  document.querySelectorAll("[data-i18n-html]").forEach(el => en[el.dataset.i18nHtml] = el.innerHTML);
  document.querySelectorAll("[data-i18n-alt]").forEach(el => en[el.dataset.i18nAlt] = el.alt);
  en["release.line"] = "Version {v}. Windows 10 and 11, 64-bit. Free and open source.";
  en["size"] = "Version {v}, {s}";
  en["units"] = ["B", "KB", "MB", "GB"];

  let lang = "en";
  let release = null;

  function size(bytes) {
    const units = (lang === "ru" ? ru : en).units;
    let i = 0;
    let n = bytes;
    while (n >= 1024 && i < units.length - 1) {
      n /= 1024;
      i++;
    }
    return n.toLocaleString(lang, { maximumFractionDigits: n < 10 ? 1 : 0 }) + " " + units[i];
  }

  function apply(next) {
    lang = next;
    const t = lang === "ru" ? ru : en;
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-i18n]").forEach(el => {
      const s = t[el.dataset.i18n];
      if (s !== undefined) el.textContent = s;
    });
    document.querySelectorAll("[data-i18n-html]").forEach(el => {
      const s = t[el.dataset.i18nHtml];
      if (s !== undefined) el.innerHTML = s;
    });
    document.querySelectorAll("[data-i18n-alt]").forEach(el => {
      const s = t[el.dataset.i18nAlt];
      if (s !== undefined) el.alt = s;
    });
    document.querySelectorAll(".lang button").forEach(b => b.setAttribute("aria-pressed", String(b.dataset.lang === lang)));
    showRelease();
  }

  function showRelease() {
    if (!release) return;
    const t = lang === "ru" ? ru : en;
    const v = release.tag_name.replace(/^v/, "");
    document.querySelectorAll("[data-release-line]").forEach(el => el.textContent = t["release.line"].replace("{v}", v));
    for (const kind of ["setup", "portable"]) {
      const asset = release.assets.find(a => kind === "setup" ? /-setup\.exe$/i.test(a.name) : /portable.*\.zip$/i.test(a.name));
      if (!asset) continue;
      document.querySelectorAll(`[data-asset="${kind}"]`).forEach(a => a.href = asset.browser_download_url);
      document.querySelectorAll(`[data-size="${kind}"]`).forEach(el => el.textContent = t.size.replace("{v}", v).replace("{s}", size(asset.size)));
    }
  }

  document.querySelectorAll(".lang button").forEach(b => b.addEventListener("click", () => {
    apply(b.dataset.lang);
    try { localStorage.setItem("flux-lang", lang); } catch (e) { /* private mode: the choice lasts the visit */ }
  }));

  let saved = null;
  try { saved = localStorage.getItem("flux-lang"); } catch (e) { /* no storage */ }
  const browser = (navigator.languages || [navigator.language || "en"]).some(l => /^(ru|uk|be|kk)\b/i.test(l)) ? "ru" : "en";
  apply(saved === "ru" || saved === "en" ? saved : browser);

  // the latest release: the buttons download its files straight away (without it they open the releases page)
  fetch(`https://api.github.com/repos/${repo}/releases/latest`, { headers: { Accept: "application/vnd.github+json" } })
    .then(r => r.ok ? r.json() : null)
    .then(r => {
      if (r && Array.isArray(r.assets)) {
        release = r;
        showRelease();
      }
    })
    .catch(() => {});
})();
