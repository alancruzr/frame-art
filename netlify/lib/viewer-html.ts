import { type ArtworkMeta, contactHref, formatSize, quickLookFragment } from "./artwork-meta";
export function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => {
    switch (ch) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      case "'": return "&#39;";
      default: return ch;
    }
  });
}

/** JSON seguro dentro de <script>. */
function scriptJSON(value: unknown): string {
  return JSON.stringify(value ?? null).replace(/</g, "\\u003c").replace(/\u2028|\u2029/g, "");
}

export function viewerHTML(title: string, posterAbs: string, meta?: ArtworkMeta): string {
  const safeTitle = escapeHtml(title || "Frame Studio");
  const size = meta ? formatSize(meta) : undefined;
  const contact = meta ? contactHref(meta.contact, meta.title) : undefined;
  const qlFragment = meta ? quickLookFragment(meta) : "#allowsContentScaling=0";
  const card = meta && (meta.artist || size || contact)
    ? `<section class="card" aria-label="Datos de la obra">
        ${meta.artist ? `<p class="card-artist">${escapeHtml(meta.artist)}</p>` : ""}
        ${size ? `<p class="card-size">${escapeHtml(size)}</p>` : ""}
        ${contact ? `<a class="btn primary card-cta" id="btn-interest" href="${escapeHtml(contact)}" rel="noopener">Me interesa</a>` : ""}
      </section>`
    : "";
  const safePoster = escapeHtml(posterAbs);
  const pageTitle = `${safeTitle} — Frame Studio`;
  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <script>
    (function () {
      function isNight() {
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) return true;
        if (window.matchMedia("(prefers-color-scheme: light)").matches) return false;
        var h = new Date().getHours();
        return h >= 19 || h < 7;
      }
      document.documentElement.setAttribute("data-theme", isNight() ? "night" : "day");
    })();
  </script>
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <title>${pageTitle}</title>
  <meta name="description" content="Mira esta obra en tu pared con AR. En iPhone abre Quick Look; en Android, Scene Viewer.">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Frame Studio">
  <meta property="og:title" content="${pageTitle}">
  <meta property="og:description" content="Abre el enlace y coloca la obra en tu pared. No hace falta instalar la app.">
  <meta property="og:image" content="${safePoster}">
  <meta property="og:image:type" content="image/jpeg">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:image" content="${safePoster}">
  <script type="module" src="https://ajax.googleapis.com/ajax/libs/model-viewer/3.5.0/model-viewer.min.js"></script>
  <style>
    :root {
      color-scheme: light dark;
      --brand-deep: #402e63;
      --brand-accent: #402e63;
      --fg: #1d1a26;
      --muted: #5f5a70;
      --bg: #f5f2fc;
      --stage: #e8e0fa;
      --btn-fg: #fff;
    }
    @media (prefers-color-scheme: dark) {
      :root:not([data-theme="day"]) {
        --brand-accent: #d1c4fa;
        --fg: #f5f2fc;
        --muted: #b9b0d0;
        --bg: #0e0c14;
        --stage: #14121c;
      }
    }
    html[data-theme="day"] {
      color-scheme: light;
      --brand-accent: #402e63;
      --fg: #1d1a26;
      --muted: #5f5a70;
      --bg: #f5f2fc;
      --stage: #e8e0fa;
    }
    html[data-theme="night"] {
      color-scheme: dark;
      --brand-accent: #d1c4fa;
      --fg: #f5f2fc;
      --muted: #b9b0d0;
      --bg: #0e0c14;
      --stage: #14121c;
    }
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      height: 100%;
      font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
      background: var(--bg);
      color: var(--fg);
    }
    .app {
      min-height: 100%;
      min-height: 100dvh;
      display: flex;
      flex-direction: column;
    }
    header.top {
      padding: calc(0.7rem + env(safe-area-inset-top)) 1.25rem 0.45rem;
    }
    .kicker {
      margin: 0;
      font-size: 0.68rem;
      font-weight: 650;
      letter-spacing: 0.14em;
      text-transform: uppercase;
      color: var(--brand-accent);
    }
    header h1 {
      font-size: 1.35rem;
      font-weight: 650;
      margin: 0.15rem 0 0;
    }
    .piece {
      margin: 0.15rem 0 0;
      color: var(--muted);
      font-size: 0.95rem;
    }
    .hero {
      position: relative;
      flex: 1;
      min-height: 0;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 0.4rem 1rem;
      background: var(--stage);
    }
    .hero img#poster {
      display: block;
      max-width: 100%;
      max-height: 100%;
      width: auto;
      height: auto;
      object-fit: contain;
      border-radius: 2px;
      box-shadow: 0 16px 48px rgba(0, 0, 0, 0.22);
    }
    .hero.hung img#poster {
      box-shadow: 0 22px 56px rgba(0, 0, 0, 0.32);
    }
    .ar-engine {
      position: absolute;
      width: 64px;
      height: 64px;
      left: 0;
      bottom: 0;
      opacity: 0;
      pointer-events: none;
      overflow: hidden;
    }
    #hidden-ar-btn { display: none !important; }
    .sr-ar {
      position: absolute;
      width: 1px;
      height: 1px;
      overflow: hidden;
      clip: rect(0, 0, 0, 0);
    }
    .card {
      margin: 0 16px 8px;
      padding: 12px 16px;
      border-radius: 18px;
      background: color-mix(in srgb, currentColor 6%, transparent);
      display: grid;
      gap: 4px;
    }
    .card p { margin: 0; }
    .card-artist { font-weight: 650; }
    .card-size { opacity: .75; font-variant-numeric: tabular-nums; }
    .card-cta { margin-top: 8px; text-align: center; text-decoration: none; min-height: 44px; display: grid; place-items: center; }
    .dock {
      background: color-mix(in srgb, var(--bg) 86%, transparent);
      -webkit-backdrop-filter: blur(18px);
      backdrop-filter: blur(18px);
      padding: 0.85rem 1.25rem calc(1.05rem + env(safe-area-inset-bottom));
    }
    .instruction {
      margin: 0 0 0.8rem;
      text-align: center;
      font-size: 0.95rem;
      line-height: 1.4;
    }
    .row {
      display: flex;
      gap: 12px;
    }
    .btn {
      appearance: none;
      flex: 1;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-height: 44px;
      padding: 0.6rem 1rem;
      border-radius: 12px;
      text-decoration: none;
      font: inherit;
      font-weight: 650;
      cursor: pointer;
      border: none;
    }
    .btn.primary {
      background: var(--brand-deep);
      color: var(--btn-fg);
    }
    .btn.secondary {
      background: transparent;
      color: var(--fg);
      border: 1px solid color-mix(in srgb, var(--fg) 22%, transparent);
    }
    .btn.quiet {
      flex: 0 0 auto;
      width: 100%;
      margin-top: 0.45rem;
      background: transparent;
      color: var(--brand-accent);
      border: none;
      font-weight: 500;
      font-size: 0.92rem;
    }
    .btn[hidden], .row[hidden] { display: none !important; }
    #missing {
      margin: 0 1.25rem 0.5rem;
      padding: 0.85rem;
      border-radius: 12px;
      border: 1px dashed color-mix(in srgb, var(--fg) 22%, transparent);
      display: none;
    }
  </style>
</head>
<body>
  <div class="app">
    <header class="top">
      <p class="kicker">Frame Studio</p>
      <h1>Mi espacio</h1>
      <p class="piece" id="title">${safeTitle}</p>
    </header>
    ${card}
    <div class="hero" id="hero">
      <img id="poster" src="poster.jpg" alt="${safeTitle}">
      <model-viewer
        class="ar-engine"
        id="viewer"
        src="model.glb"
        ios-src="model.usdz"
        poster="poster.jpg"
        alt="${safeTitle}"
        ar
        ar-modes="quick-look scene-viewer webxr"
        ar-placement="wall"
        ar-scale="fixed"
        shadow-intensity="0.32"
        exposure="1.2"
        environment-image="neutral"
      >
        <button id="hidden-ar-btn" slot="ar-button" type="button" tabindex="-1" aria-hidden="true"></button>
      </model-viewer>
      <a id="ios-ar" class="sr-ar" rel="ar" href="model.usdz${escapeHtml(qlFragment)}">
        <img alt="" width="1" height="1" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=">
      </a>
    </div>
    <div id="missing">Aún no hay una imagen de esta obra. El artista tiene que compartir una obra publicada.</div>
    <div class="dock">
      <p class="instruction" id="instruction">Apunta a una pared y deja el teléfono quieto unos segundos.</p>
      <div class="row" id="phase-search">
        <button type="button" class="btn primary" id="btn-place">Colocar aquí</button>
      </div>
      <div class="row" id="phase-placed" hidden>
        <button type="button" class="btn secondary" id="btn-move">Mover</button>
        <button type="button" class="btn primary" id="btn-pin">Fijar</button>
      </div>
      <div class="row" id="phase-pinned" hidden>
        <button type="button" class="btn secondary" id="btn-move-again">Mover a otra pared</button>
      </div>
      <button type="button" class="btn quiet" id="btn-app" hidden>Mayor precisión en Frame Studio</button>
    </div>
  </div>
  <script>
    (function () {
      var searchCopy = "Apunta a una pared y deja el teléfono quieto unos segundos.";
      var placedCopy = "Así se ve colgada. Fíjala, o pulsa Mover para otra pared.";

      function isNight() {
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) return true;
        if (window.matchMedia("(prefers-color-scheme: light)").matches) return false;
        var h = new Date().getHours();
        return h >= 19 || h < 7;
      }
      function applyTheme() {
        var night = isNight();
        document.documentElement.setAttribute("data-theme", night ? "night" : "day");
        var viewer = document.getElementById("viewer");
        if (!viewer) return;
        viewer.setAttribute("exposure", night ? "0.72" : "1.2");
        viewer.setAttribute("shadow-intensity", night ? "0.12" : "0.32");
        viewer.setAttribute("environment-image", "neutral");
      }
      applyTheme();
      try {
        window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyTheme);
        window.matchMedia("(prefers-color-scheme: light)").addEventListener("change", applyTheme);
      } catch (e) {}

      var params = new URLSearchParams(location.search);
      var titleEl = document.getElementById("title");
      var title = params.get("title") || (titleEl && titleEl.textContent) || "Frame Studio";
      var QL_FRAGMENT = ${scriptJSON(qlFragment)};
      var CONTACT_URL = ${scriptJSON(contact)};
      // Solo rutas relativas o https: evita inyectar javascript: en enlaces vía query string.
      function safeAsset(value, fallback) {
        if (!value) return fallback;
        try {
          var u = new URL(value, location.href);
          return u.protocol === "https:" || u.origin === location.origin ? value : fallback;
        } catch (e) { return fallback; }
      }
      var glb = safeAsset(params.get("glb"), "model.glb");
      var usdz = safeAsset(params.get("usdz"), "model.usdz");
      var poster = safeAsset(params.get("poster"), "poster.jpg");

      document.title = title + " \u2014 Frame Studio";
      if (titleEl) titleEl.textContent = title;
      var posterImg = document.getElementById("poster");
      if (posterImg) {
        posterImg.src = poster;
        posterImg.alt = title;
      }

      var viewer = document.getElementById("viewer");
      viewer.src = glb;
      viewer.setAttribute("ios-src", usdz);
      viewer.setAttribute("poster", poster);
      viewer.setAttribute("alt", title);
      applyTheme();

      var ios = document.getElementById("ios-ar");
      ios.href = usdz + QL_FRAGMENT;
      // Banner "Me interesa" de AR Quick Look (callToAction): Apple envía este mensaje al <a rel="ar">.
      ios.addEventListener("message", function (event) {
        if (event.data === "_apple_ar_quicklook_button_tapped" && CONTACT_URL) {
          location.href = CONTACT_URL;
        }
      }, false);
      var glbURL = new URL(glb, location.href).href;
      var intent =
        "intent://arvr.google.com/scene-viewer/1.2?file=" +
        encodeURIComponent(glbURL) +
        "&mode=ar_preferred&title=" + encodeURIComponent(title) +
        "&enable_vertical_placement=true" +
        "#Intent;scheme=https;package=com.google.android.googlequicksearchbox;action=android.intent.action.VIEW;S.browser_fallback_url=" +
        encodeURIComponent(location.href) +
        ";end;";

      var ua = navigator.userAgent || "";
      var isIOS = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
      var isAndroid = /Android/i.test(ua);

      var instruction = document.getElementById("instruction");
      var hero = document.getElementById("hero");
      var rowSearch = document.getElementById("phase-search");
      var rowPlaced = document.getElementById("phase-placed");
      var rowPinned = document.getElementById("phase-pinned");

      function setPhase(next) {
        rowSearch.hidden = next !== "search";
        rowPlaced.hidden = next !== "placed";
        rowPinned.hidden = next !== "pinned";
        if (next === "search") {
          instruction.textContent = searchCopy;
          hero.classList.remove("hung");
          viewer.setAttribute("camera-controls", "");
        } else if (next === "placed") {
          instruction.textContent = placedCopy;
          hero.classList.remove("hung");
        } else {
          instruction.textContent = placedCopy;
          hero.classList.add("hung");
          viewer.removeAttribute("camera-controls");
        }
      }

      function launchAR() {
        if (isAndroid) {
          window.location.href = intent;
          return;
        }
        if (viewer && typeof viewer.activateAR === "function") {
          try {
            viewer.activateAR();
            return;
          } catch (err) {}
        }
        if (isIOS && ios) ios.click();
      }

      document.getElementById("btn-place").addEventListener("click", function () {
        setPhase("placed");
        launchAR();
      });
      document.getElementById("btn-move").addEventListener("click", function () {
        setPhase("placed");
        launchAR();
      });
      document.getElementById("btn-move-again").addEventListener("click", function () {
        setPhase("placed");
        launchAR();
      });
      document.getElementById("btn-pin").addEventListener("click", function () {
        setPhase("pinned");
        try { if (navigator.vibrate) navigator.vibrate(10); } catch (err) {}
      });

      posterImg.addEventListener("error", function () {
        document.getElementById("missing").style.display = "block";
      });

      var btnApp = document.getElementById("btn-app");
      function studioArtworkFromPath() {
        var parts = location.pathname.split("/").filter(Boolean);
        if (parts.length < 2) return null;
        if (parts[0] === "o" || parts[0] === "api" || parts[0] === ".well-known") return null;
        return { studio: parts[0], artwork: parts[1] };
      }
      var sharePath = studioArtworkFromPath();
      if (isIOS && sharePath && btnApp) {
        btnApp.hidden = false;
        btnApp.addEventListener("click", function () {
          var scheme = "framestudio://" + sharePath.studio + "/" + sharePath.artwork;
          var httpsURL = "https://frame-studio.netlify.app/" + sharePath.studio + "/" + sharePath.artwork + "/";
          var iframe = document.createElement("iframe");
          iframe.setAttribute("aria-hidden", "true");
          iframe.style.display = "none";
          iframe.src = scheme;
          document.body.appendChild(iframe);
          var schemeLink = document.createElement("a");
          schemeLink.href = scheme;
          schemeLink.style.display = "none";
          document.body.appendChild(schemeLink);
          schemeLink.click();
          var httpsLink = document.createElement("a");
          httpsLink.href = httpsURL;
          httpsLink.style.display = "none";
          document.body.appendChild(httpsLink);
          httpsLink.click();
          setTimeout(function () {
            if (iframe.parentNode) iframe.parentNode.removeChild(iframe);
            if (schemeLink.parentNode) schemeLink.parentNode.removeChild(schemeLink);
            if (httpsLink.parentNode) httpsLink.parentNode.removeChild(httpsLink);
          }, 1500);
        });
      }
    })();
  </script>
  <script>
    (function () {
      try {
        var parts = location.pathname.split("/").filter(Boolean);
        if (parts.length < 2) return;
        var params = new URLSearchParams(location.search);
        var owner = false;
        try {
          if (params.has("owner")) localStorage.setItem("fs-owner:" + parts[0], "1");
          owner = localStorage.getItem("fs-owner:" + parts[0]) === "1";
        } catch (e) {}
        var body = JSON.stringify({ studio: parts[0], artwork: parts[1], owner: owner });
        if (navigator.sendBeacon) {
          navigator.sendBeacon("/api/views", new Blob([body], { type: "application/json" }));
        } else {
          fetch("/api/views", { method: "POST", headers: { "content-type": "application/json" }, body: body, keepalive: true });
        }
      } catch (e) {}
    })();
  </script>
</body>
</html>
`;
}
