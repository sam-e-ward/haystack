#!/usr/bin/env bash
set -euxo pipefail

cd "$(git rev-parse --show-toplevel)"

if [[ -z "${PYTHON:-}" && -x /usr/bin/python3 ]]; then
  export PYTHON=/usr/bin/python3
fi

yarn
./build-scripts/edit-npm-modules.sh
node --max-old-space-size=8192 ./node_modules/gulp/bin/gulp.js haystack-editor-darwin-x64-min
