#!/bin/bash
# Wanderer web build for testers (GitHub Pages, gh-pages branch, /wanderer/).
#
#   tools/build_wanderer_web.sh            build only -> /tmp/wanderer_web
#   tools/build_wanderer_web.sh --deploy   build, then commit it to gh-pages/wanderer/
#
# Single-threaded Godot web export (no COOP/COEP headers needed on Pages);
# game/tools/ is excluded by the "Web" preset. The Anime TD at the site root is
# left untouched: only the wanderer/ folder of gh-pages is replaced.
# Needs: Godot 4.3 at $GODOT and the 4.3 web_nothreads export templates.
set -euo pipefail
GODOT=${GODOT:-/tmp/claude-0/godot/Godot_v4.3-stable_linux.x86_64}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-/tmp/wanderer_web}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

SHA=$(git -C "$ROOT" rev-parse --short HEAD)
NOW=$(date -u +"%Y-%m-%d %H:%M UTC")
cp -r "$ROOT/game" "$WORK/game"
rm -rf "$WORK/game/.godot"
# Build stamp (testers quote it in feedback); VERSION stays as committed.
sed -i "s/^const COMMIT := .*/const COMMIT := \"$SHA\"/; s/^const BUILT := .*/const BUILT := \"$NOW\"/" "$WORK/game/scripts/build_info.gd"

rm -rf "$OUT" && mkdir -p "$OUT"
cd "$WORK/game"
timeout 900 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 1200 "$GODOT" --headless --path . --export-release "Web" "$OUT/index.html" 2>&1 | grep -E "ERROR|error|savepack|export" | grep -v "RID allocations" | tail -5 || true
test -f "$OUT/index.pck" || { echo "export failed"; exit 1; }

echo "--- build $SHA ($NOW) ---"
ls -la "$OUT"
TOTAL=$(du -cb "$OUT"/* | tail -1 | cut -f1)
GZ=0
for f in "$OUT"/*.wasm "$OUT"/*.pck "$OUT"/*.js; do GZ=$((GZ + $(gzip -c "$f" | wc -c))); done
echo "total $((TOTAL / 1024 / 1024)) MB raw, ~$((GZ / 1024 / 1024)) MB transferred (gzip estimate for wasm/pck/js)"

if [ "${1:-}" = "--deploy" ]; then
  cd "$ROOT"
  git fetch -q origin gh-pages:refs/remotes/origin/gh-pages
  WT=$(mktemp -d)
  git worktree add -q -f "$WT" origin/gh-pages
  rm -rf "$WT/wanderer"
  mkdir -p "$WT/wanderer"
  cp -r "$OUT"/* "$WT/wanderer/"
  cd "$WT"
  git add -A wanderer
  git -c user.name="${GIT_AUTHOR_NAME:-Claude}" -c user.email="${GIT_AUTHOR_EMAIL:-noreply@anthropic.com}" commit -q -m "Update Wanderer web build ($SHA)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01RH6H1f1DDDW68nBhG3YZ8E" || echo "nothing to deploy"
  git push -q origin HEAD:gh-pages
  cd "$ROOT"
  git worktree remove --force "$WT"
  echo "deployed: https://zwoodjr.github.io/sprite-lane/wanderer/"
fi
