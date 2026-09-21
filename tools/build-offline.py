#!/usr/bin/env python3
"""Bundle Spirit Lane into a single offline HTML file for Safari / litterbox."""
from __future__ import annotations

import base64
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


def main() -> None:
    html = (ROOT / "index.html").read_text(encoding="utf-8")
    css = (ROOT / "styles.css").read_text(encoding="utf-8")
    sprites = (ROOT / "sprites.js").read_text(encoding="utf-8")
    game = (ROOT / "game.js").read_text(encoding="utf-8")
    font = (ROOT / "fonts" / "PressStart2P.woff2").read_bytes()
    b64 = base64.b64encode(font).decode("ascii")
    css = css.replace(
        'url("fonts/PressStart2P.woff2")',
        f'url("data:font/woff2;base64,{b64}")',
    )

    html = html.replace(
        '<link rel="stylesheet" href="styles.css" />',
        f"<style>\n{EXTRA_CSS}\n{css}\n</style>",
    )
    # Manifest is optional; avoid broken relative fetch in single-file hosts.
    html = html.replace(
        '<link rel="manifest" href="manifest.webmanifest" />',
        "",
    )
    # index.html already includes #boot-splash — do not insert a second one.
    html = html.replace(
        '<script src="sprites.js"></script>',
        f"<script>\n{sprites}\n</script>",
    )
    html = html.replace(
        '<script src="game.js"></script>',
        f"<script>\n{game}\n</script>\n{BOOT_TAIL}",
    )

    OUT.write_text(html, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
    print("data-font", "data:font/woff2" in html)
    print("splash", "boot-splash" in html)
    print("gate", "rotate-gate" in html)


if __name__ == "__main__":
    main()
