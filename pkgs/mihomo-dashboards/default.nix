{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchzip,
  python3,
}:

let
  metacubexdVersion = "1.244.2";
  zashboardVersion = "3.2.0";
  yacdGhPagesRev = "8316677ff80fdfcb3ceedb133f6bdc6a5cc3ee0c";

  metacubexdDist = fetchzip {
    url = "https://github.com/MetaCubeX/metacubexd/releases/download/v${metacubexdVersion}/compressed-dist.tgz";
    hash = "sha256-f24Jqdd8+MEO6KfqxV/O3JXOvX2HHLLouYi5fq2NXyo=";
    stripRoot = false;
  };

  zashboardDist = fetchzip {
    url = "https://github.com/Zephyruso/zashboard/releases/download/v${zashboardVersion}/dist.zip";
    hash = "sha256-P4KLnVkQCXPXsxlRiigCMCELO9RNC4wLVCGcpgcIC1A=";
    stripRoot = false;
  };

  yacdMetaDist = fetchFromGitHub {
    owner = "MetaCubeX";
    repo = "Yacd-meta";
    rev = yacdGhPagesRev;
    hash = "sha256-XoKBw5GdrgvEJl5aRt7f5vDNbpvPLdsQMaoWCgG3SBg=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "mihomo-dashboards";
  version = "${metacubexdVersion}-${zashboardVersion}-${lib.substring 0 7 yacdGhPagesRev}";

  nativeBuildInputs = [ python3 ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"/{metacubexd,yacd,zashboard}

    cp -R ${metacubexdDist}/. "$out/metacubexd/"
    cp -R ${zashboardDist}/dist/. "$out/zashboard/"
    cp -R ${yacdMetaDist}/. "$out/yacd/"

    chmod -R u+w "$out"

    cat > "$out/metacubexd/config.js" <<'EOF'
window.__METACUBEXD_CONFIG__ = {
  defaultBackendURL: typeof window !== "undefined" ? window.location.origin + "/api" : "/api"
}
EOF

    python3 - <<'PY' "$out/metacubexd/index.html" "$out/metacubexd/200.html" "$out/metacubexd/404.html"
from pathlib import Path
import sys

marker = "<script>window.__METACUBEXD_CONFIG__ = window.__METACUBEXD_CONFIG__ || { defaultBackendURL:"
inject = """
<script>
  (function () {
    const endpoint = {
      id: "tailnet-dashboard",
      name: "ai-server",
      url: window.location.origin + "/api",
      secret: "",
    }
    try {
      localStorage.setItem("endpointList", JSON.stringify([endpoint]))
      localStorage.setItem("selectedEndpoint", endpoint.id)
    } catch (_) {}
  })()
</script>
""".strip()

for arg in sys.argv[1:]:
    path = Path(arg)
    text = path.read_text()
    start = text.find(marker)
    if start == -1:
        raise SystemExit(f"metacubexd marker not found in {path}")
    end = text.find("</script>", start)
    if end == -1:
        raise SystemExit(f"metacubexd closing script marker not found in {path}")
    end += len("</script>")
    path.write_text(text[:end] + "\\n" + inject + text[end:])
PY

    substituteInPlace "$out/yacd/index.html" \
      --replace-fail 'data-base-url="http://127.0.0.1:9090"' 'data-base-url="/api"'

    python3 - <<'PY' "$out/yacd/index.html"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = '<script type="module" crossorigin src="./assets/'
inject = """
    <script>
      (function () {
        const state = {
          selectedClashAPIConfigIndex: 0,
          clashAPIConfigs: [{
            baseURL: window.location.origin + "/api",
            secret: "",
            addedAt: 0,
          }],
        }
        try {
          localStorage.setItem("yacd.metacubex.one", JSON.stringify(state))
        } catch (_) {}
      })()
    </script>
""".strip()
if marker not in text:
    raise SystemExit("yacd index marker not found")
path.write_text(text.replace(marker, inject + "\n    " + marker, 1))
PY

    python3 - <<'PY' "$out/zashboard/index.html"
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
marker = '<script type="module" crossorigin src="./assets/index-DKHMNGQK.js"></script>'
inject = """
    <script>
      (function () {
        const protocol = window.location.protocol.replace(":", "") || "https"
        const port = window.location.port || (protocol === "https" ? "443" : "80")
        const backend = {
          uuid: "tailnet-dashboard",
          protocol,
          host: window.location.hostname,
          port,
          secondaryPath: "/api",
          password: "",
          label: "ai-server",
          disableUpgradeCore: true,
        }
        localStorage.setItem("setup/api-list", JSON.stringify([backend]))
        localStorage.setItem("setup/active-uuid", backend.uuid)
      })()
    </script>
""".strip()
if marker not in text:
    raise SystemExit("zashboard index marker not found")
path.write_text(text.replace(marker, inject + "\n    " + marker, 1))
PY

    for register_sw in "$out/zashboard/registerSW.js" "$out/yacd/registerSW.js"; do
      if [ -f "$register_sw" ]; then
        cat > "$register_sw" <<'EOF'
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.getRegistrations().then((registrations) => {
    registrations.forEach((registration) => registration.unregister())
  }).catch(() => {})
}
EOF
      fi
    done

    for sw in "$out/zashboard/sw.js" "$out/yacd/sw.js"; do
      if [ -f "$sw" ]; then
        cat > "$sw" <<'EOF'
self.addEventListener("install", (event) => {
  self.skipWaiting()
})
self.addEventListener("activate", (event) => {
  event.waitUntil(
    self.registration.unregister().then(() => self.clients.matchAll()).then((clients) => {
      clients.forEach((client) => client.navigate(client.url))
    })
  )
})
EOF
      fi
    done

    cat > "$out/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>ai-server Mihomo Dashboards</title>
    <style>
      :root {
        color-scheme: dark;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        background:
          radial-gradient(circle at top, rgba(99, 102, 241, 0.28), transparent 38%),
          linear-gradient(180deg, #111827 0%, #09090b 100%);
        color: #f5f7fb;
      }
      main {
        width: min(720px, calc(100vw - 32px));
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 24px;
        padding: 32px;
        backdrop-filter: blur(14px);
        background: rgba(17, 24, 39, 0.82);
        box-shadow: 0 28px 64px rgba(0, 0, 0, 0.35);
      }
      h1 {
        margin: 0 0 10px;
        font-size: clamp(28px, 4vw, 40px);
      }
      p {
        margin: 0 0 24px;
        color: #c9d1e3;
        line-height: 1.6;
      }
      .grid {
        display: grid;
        gap: 14px;
      }
      a {
        display: block;
        padding: 18px 20px;
        border-radius: 18px;
        color: inherit;
        text-decoration: none;
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.08);
        transition: transform 140ms ease, border-color 140ms ease, background 140ms ease;
      }
      a:hover {
        transform: translateY(-1px);
        background: rgba(255, 255, 255, 0.07);
        border-color: rgba(129, 140, 248, 0.55);
      }
      strong {
        display: block;
        font-size: 17px;
        margin-bottom: 4px;
      }
      small {
        color: #aab6cf;
      }
      code {
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        font-size: 13px;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>ai-server Mihomo</h1>
      <p>
        These dashboards are hosted on the tailnet-only controller endpoint. Open one of
        them below.
      </p>
      <div class="grid">
        <a href="/zashboard/">
          <strong>zashboard</strong>
          <small>Modern dashboard with the backend preloaded via <code>/api</code>.</small>
        </a>
        <a href="/metacubexd/">
          <strong>MetaCubeXD</strong>
          <small>Official MetaCubeX dashboard using the same-origin <code>/api</code>.</small>
        </a>
        <a href="/yacd/">
          <strong>Yacd-meta</strong>
          <small>Classic dashboard patched to talk to <code>/api</code> directly.</small>
        </a>
      </div>
    </main>
  </body>
</html>
EOF

    runHook postInstall
  '';

  meta = {
    description = "Tailnet-hosted static dashboard bundle for Mihomo";
    homepage = "https://github.com/MetaCubeX/metacubexd";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
