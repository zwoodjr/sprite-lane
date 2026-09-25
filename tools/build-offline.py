#!/usr/bin/env python3
"""Bundle Spirit Lane into a single offline HTML file for Safari / litterbox."""
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = Path("/tmp/spirit-lane-offline.html")

EXTRA_CSS = """
/* Boot-safe: never collapse to an empty viewport */
html, body { background: #120e0b !important; }
#app {
  min-height: 100vh;
  min-height: 100dvh;
  visibility: visible !important;
  opacity: 1 !important;
}
#playfield, #stage, #rail, #frame, #game { visibility: visible !important; }
#boot-splash {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #120e0b;
  color: #e8c56a;
  font-family: "Courier New", Courier, monospace;
  font-size: 14px;
  letter-spacing: 0.08em;
  transition: opacity 0.25s ease;
}
#boot-splash.hide { opacity: 0; pointer-events: none; }
"""

BOOT_TAIL = """
<script>
(function () {
  function hideAll() {
    document.querySelectorAll("#boot-splash").forEach(function (s) {
      s.classList.add("hide");
      setTimeout(function () {
        if (s && s.parentNode) s.parentNode.removeChild(s);
      }, 400);
    });
  }
  if (window.SpiritLane) hideAll();
  else setTimeout(hideAll, 0);
  setTimeout(function () {
    var b = document.getElementById("boot-error");
    if (b && !window.SpiritLane) {
      b.hidden = false;
      if (!b.textContent) {
        b.textContent = "Game failed to start. Hard-refresh and try again.";
      }
      hideAll();
    }
  }, 2500);
})();
</script>
"""


def data_url(path: Path) -> str:
    raw = path.read_bytes()
    mime = "image/png" if path.suffix.lower() == ".png" else "application/octet-stream"
    return f"data:{mime};base64,{base64.b64encode(raw).decode('ascii')}"


def build_endgame_js() -> str:
    """Inline endgame-art.js with PNG paths rewritten to data URLs."""
    import re

    src = (ROOT / "assets" / "hero" / "endgame-art.js").read_text(encoding="utf-8")
    hero_dir = ROOT / "assets" / "hero"

    def repl(match: re.Match[str]) -> str:
        rel = match.group(0)
        path = ROOT / rel
        if not path.exists():
            path = hero_dir / Path(rel).name
        if not path.exists():
            return rel
        return data_url(path)

    return re.sub(r"assets/hero/(?:models/)?[A-Za-z0-9._-]+\.png", repl, src)


def build_html() -> str:
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    css = (ROOT / "styles.css").read_text(encoding="utf-8")
    sprites = (ROOT / "sprites.js").read_text(encoding="utf-8")
    endgame = build_endgame_js()
    game = (ROOT / "game.js").read_text(encoding="utf-8")
    font = (ROOT / "fonts" / "PressStart2P.woff2").read_bytes()
    b64 = base64.b64encode(font).decode("ascii")
    css = css.replace(
        'url("fonts/PressStart2P.woff2")',
        f'url("data:font/woff2;base64,{b64}")',
    )

    html = html.replace(
        "<html lang=\"en\">",
        "<html lang=\"en\" data-offline-bundle=\"1\">",
        1,
    )
    html = html.replace(
        '<link rel="stylesheet" href="styles.css" />',
        f"<style>\n{EXTRA_CSS}\n{css}\n</style>",
    )
    # Manifest + SW need extra files — strip for single-file hosts / file://
    html = html.replace(
        '<link rel="manifest" href="manifest.webmanifest" />',
        "",
    )
    html = html.replace(
        '<script src="sprites.js"></script>',
        f"<script>\n{sprites}\n</script>",
    )
    html = html.replace(
        '<script src="assets/hero/endgame-art.js"></script>',
        f"<script>\n{endgame}\n</script>",
    )
    html = html.replace(
        '<script src="game.js"></script>',
        f"<script>\n{game}\n</script>\n{BOOT_TAIL}",
    )
    # Remove SW registration block from the bundled copy (no sw.js on litterbox).
    html = html.replace(
        """      // Cache assets when served over http(s) so a revisit can work offline.
      if (
        location.protocol !== "file:" &&
        "serviceWorker" in navigator &&
        !document.documentElement.hasAttribute("data-offline-bundle")
      ) {
        navigator.serviceWorker.register("./sw.js").catch(function () {});
      }
""",
        "",
    )
    return html


def main() -> None:
    html = build_html()
    # Embed pristine source so Save Offline works with zero network.
    # Escape "<" so a "</script>" inside the payload cannot break out of this tag.
    # Append before the FINAL </body> only — game.js may contain the substring
    # "</body>" inside strings (e.g. install-banner helpers).
    payload = json.dumps(html).replace("<", "\\u003c")
    marker = "</body>"
    idx = html.rfind(marker)
    if idx < 0:
        raise SystemExit("offline build: no </body> found")
    html = (
        html[:idx]
        + f"<script>window.__SPIRIT_LANE_SOURCE__ = {payload};</script>\n"
        + html[idx:]
    )
    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
    print("data-font", "data:font/woff2" in html)
    print("splash", "boot-splash" in html)
    print("bundle-attr", 'data-offline-bundle="1"' in html)
    print("source-embed", "__SPIRIT_LANE_SOURCE__" in html)
    print("gate", "rotate-gate" in html)


if __name__ == "__main__":
    main()
