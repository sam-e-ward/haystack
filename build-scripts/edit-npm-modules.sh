#!/usr/bin/env bash
set -euxo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
VENDORED_PIXI_DIST="$REPO_ROOT/vendor/pixijs-dist"

cd "$REPO_ROOT"

if [[ ! -d "$VENDORED_PIXI_DIST" ]]; then
  echo "Missing vendored pixi.js dist at $VENDORED_PIXI_DIST" >&2
  exit 1
fi

if [[ ! -d node_modules/pixi.js ]]; then
  echo "Missing node_modules/pixi.js. Run yarn before this script." >&2
  exit 1
fi

rm -rf node_modules/pixi.js/dist
cp -R "$VENDORED_PIXI_DIST" node_modules/pixi.js/dist

if [[ -d node_modules/@pixi ]]; then
  find node_modules/@pixi -name '*.d.ts' -type f -delete
fi
