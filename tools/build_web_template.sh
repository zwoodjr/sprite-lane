#!/bin/bash
# Slim Godot web export template for Wanderer (single-threaded, release).
#
#   tools/build_web_template.sh
#
# Builds Godot 4.3-stable (the exact engine the project and its stock export
# templates use) for the web with:
#   threads=no, disable_3d, optimize=size, LTO, and the feature build profile
#   game/tools/web/wanderer.build (unused classes + modules off; text_server_fb).
# Output: $OUT (default ~/.local/share/wanderer/web_nothreads_release.zip).
# tools/build_wanderer_web.sh exports with it automatically when it exists.
# Binaries are not committed; re-run this to rebuild them (~1-2 h on 2 cores).
#
# Needs: git, python3 + scons (pip install scons), emsdk 3.1.64 (same as the
# official 4.3 templates; set EMSDK) and optionally wasm-opt (binaryen).
# LTO linking needs ~10 GB of RAM+swap.
# Regenerate the profile after big engine-API changes in the game with:
#   Godot_v4.3-stable --headless --dump-extension-api
#   python3 game/tools/web/gen_build_profile.py extension_api.json > game/tools/web/wanderer.build
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
GODOT_REF=${GODOT_REF:-4.3-stable}
GODOT_COMMIT=77dcf97d82cbfe4e4615475fa52ca03da645dbd8
SRC=${GODOT_SRC:-/tmp/godot-$GODOT_REF-src}
OUT=${OUT:-$HOME/.local/share/wanderer/web_nothreads_release.zip}
PROFILE="$ROOT/game/tools/web/wanderer.build"
JOBS=${JOBS:-$(nproc)}

if [ -n "${EMSDK:-}" ] && [ -f "$EMSDK/emsdk_env.sh" ]; then
  # shellcheck disable=SC1091
  source "$EMSDK/emsdk_env.sh" >/dev/null
fi
command -v emcc >/dev/null || { echo "emcc not found (install emsdk 3.1.64 or set EMSDK)"; exit 1; }
command -v scons >/dev/null || { echo "scons not found (pip install scons)"; exit 1; }

if [ ! -d "$SRC/.git" ]; then
  git clone -q --depth 1 --branch "$GODOT_REF" https://github.com/godotengine/godot.git "$SRC"
fi
test "$(git -C "$SRC" rev-parse HEAD)" = "$GODOT_COMMIT" || { echo "engine source is not $GODOT_REF"; exit 1; }

EMV=$(emcc --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "emcc: $EMV"
# The official 4.3 templates use emsdk 3.1.64. Ubuntu's emscripten 3.1.6
# (with LLVM 15) links but the page dies at start ("callMain is not defined":
# clang renames main to __main_argc_argv, which that emcc doesn't expect).
if [ "$(printf '%s\n3.1.39\n' "$EMV" | sort -V | head -1)" != "3.1.39" ] && [ -z "${ALLOW_OLD_EMCC:-}" ]; then
  echo "emcc $EMV is too old: install emsdk 3.1.64 (./emsdk install 3.1.64 && ./emsdk activate 3.1.64) and set EMSDK"
  exit 1
fi
cd "$SRC"
scons platform=web target=template_release threads=no production=yes \
  optimize=size lto=full debug_symbols=no \
  build_profile="$PROFILE" -j"$JOBS"

ZIP=bin/godot.web.template_release.wasm32.nothreads.zip
test -f "$ZIP"
if command -v wasm-opt >/dev/null; then
  T=$(mktemp -d)
  unzip -q "$ZIP" -d "$T"
  before=$(stat -c%s "$T/godot.wasm")
  wasm-opt -Oz --enable-bulk-memory --enable-sign-ext --enable-mutable-globals \
    --enable-nontrapping-float-to-int --enable-exception-handling "$T/godot.wasm" -o "$T/godot.opt.wasm" \
    && mv "$T/godot.opt.wasm" "$T/godot.wasm"
  echo "wasm-opt: $before -> $(stat -c%s "$T/godot.wasm") bytes"
  (cd "$T" && zip -q -r "$SRC/$ZIP.opt" .)
  mv "$SRC/$ZIP.opt" "$ZIP"
  rm -rf "$T"
fi
mkdir -p "$(dirname "$OUT")"
cp "$ZIP" "$OUT"
unzip -l "$OUT"
echo "template: $OUT"
