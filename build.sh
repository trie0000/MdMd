#!/usr/bin/env bash
# build.sh — compile app.src.js -> app.js with build metadata baked in.
# Reads git short hash, ISO timestamp, and the current sw.js CACHE_VERSION
# and threads them into the bundle via esbuild --define. The values surface
# in the bottom-right status bar and the Help -> バージョン情報 dialog.
set -euo pipefail
cd "$(dirname "$0")"

HASH="$(git rev-parse --short HEAD 2>/dev/null || echo dev)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
VER="$(sed -nE "s/.*CACHE_VERSION = ['\"]([^'\"]+)['\"].*/\1/p" sw.js | head -n1)"
VER="${VER:-dev}"

# Append a dirty-tree marker so a build off uncommitted changes is obvious.
if ! git diff --quiet HEAD -- app.src.js styles.css index.html sw.js manifest.json 2>/dev/null; then
  HASH="${HASH}+dirty"
fi

echo "Building MdMd ${VER} · ${HASH} (${DATE})"

npx --yes esbuild@0.24 app.src.js \
  --minify --target=es2020 \
  --define:__MDMD_BUILD_HASH__="\"${HASH}\"" \
  --define:__MDMD_BUILD_DATE__="\"${DATE}\"" \
  --define:__MDMD_BUILD_VER__="\"${VER}\"" \
  --outfile=app.js

echo "Done -> app.js"
