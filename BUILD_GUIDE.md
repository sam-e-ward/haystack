# Haystack Editor — Build Guide for macOS

This documents everything learned while attempting to build Haystack Editor from source on macOS (Apple Silicon). The original team has pivoted away from this editor, so this fork exists to keep it alive.

## Prerequisites

| Tool      | Version                    | Notes                                                                                  |
| --------- | -------------------------- | -------------------------------------------------------------------------------------- |
| Node.js   | **20.14.0** (per `.nvmrc`) | `nvm install 20.14.0 && nvm use 20.14.0` — do NOT use Node 24+                         |
| Yarn      | **1.x**                    | `npm install -g yarn`                                                                  |
| Python    | 3.x                        | Required for node-gyp. If node-gyp cannot find it, run with `PYTHON=/usr/bin/python3`. |
| Xcode CLT | Latest                     | `xcode-select --install`                                                               |

### macOS C++ Header Fix

On recent macOS versions, clang may fail to find `<functional>` and other C++ stdlib headers. Symptoms: `fatal error: 'functional' file not found` during `yarn install`.

**Diagnosis:**

```bash
echo '#include <functional>' | clang++ -x c++ -std=c++17 -fsyntax-only -
```

**Fix:** The SDK symlink may be correct but clang searches the wrong include path. Symlink the SDK headers:

```bash
sudo rm -rf /Library/Developer/CommandLineTools/usr/include/c++/v1
sudo ln -s /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk/usr/include/c++/v1 \
           /Library/Developer/CommandLineTools/usr/include/c++/v1
```

Adjust `MacOSX15.4.sdk` to your actual SDK version (`ls /Library/Developer/CommandLineTools/SDKs/`).

## Critical: Modified pixi.js

**This is the #1 thing that blocks the build.** Haystack uses a [custom fork of pixi.js](https://github.com/haystackeditor/pixijs) that must be built and copied into `node_modules/`. Without it, the app opens to a **blank white window** with no errors — the canvas renderer silently fails.

The script `build-scripts/edit-npm-modules.sh` replaces the stock pixi.js package output with the vendored Haystack build:

```bash
rm -rf node_modules/pixi.js/dist
cp -R vendor/pixijs-dist node_modules/pixi.js/dist
find node_modules/@pixi -name '*.d.ts' -type f -delete
```

### Vendored pixi dist

This repo now vendors the built pixi.js output in `vendor/pixijs-dist/` so a sibling `../pixijs` checkout is no longer required for normal Haystack builds.

The vendored files came from:

- Source: https://github.com/haystackeditor/pixijs
- Commit: `11a1a9d5a741ef3563321514ac7d925bb9bbc165`
- Package: `pixi.js@8.1.6`
- Build command: `npm ci && npm run build` under Node.js `20.14.0`

To refresh the vendored files:

```bash
cd /Users/samward/Dev
git clone https://github.com/haystackeditor/pixijs   # if needed
cd pixijs
nvm use 20.14.0
npm ci
npm run build
cd /Users/samward/Dev/haystack
rm -rf vendor/pixijs-dist
cp -R ../pixijs/dist vendor/pixijs-dist
```

## Build Steps

### Dev build (run from source — fast iteration)

```bash
nvm use 20.14.0
PYTHON=/usr/bin/python3 yarn              # first install may need explicit Python for node-gyp
bash build-scripts/edit-npm-modules.sh   # CRITICAL — must run after every yarn
yarn compile                              # compiles to out/
./scripts/haystack-editor.sh              # launches with Electron
```

### Production build (bundled .app)

The repo includes convenience scripts:

```bash
bash build-scripts/build-darwin-arm64.sh   # arm64
bash build-scripts/build-darwin-x64.sh     # Intel
```

These run `yarn`, `edit-npm-modules.sh`, then `gulp haystack-editor-darwin-arm64-min`.

The output lands in `../VSCode-darwin-arm64/Haystack Editor.app`.

Install:

```bash
cp -R "../VSCode-darwin-arm64/Haystack Editor.app" /Applications/
xattr -cr "/Applications/Haystack Editor.app"   # clear quarantine
```

## Known Build Issues

### 1. Mangler crashes on @pixi `.d.ts` files

**Symptom:** `Error: OVERLAPPING edit` in `@pixi/settings/lib/ICanvas.d.ts` after 30-40 minutes.

**Cause:** The TypeScript mangler (used for minification) generates conflicting rename edits for pixi type declarations. The `edit-npm-modules.sh` script is supposed to delete `@pixi/*.d.ts` files to prevent this — if it wasn't run, or was run before `yarn` installed node_modules, these files will still be present.

**Fix:** Run `edit-npm-modules.sh` after `yarn`. If it still fails, disable mangling:

In `build/gulpfile.compile.js`, change:

```js
const compileBuildTask = task.define(
  "compile-build",
  makeCompileBuildTask(false),
)
```

to:

```js
const compileBuildTask = task.define(
  "compile-build",
  makeCompileBuildTask(true),
)
```

Or use the existing `compile-build-pr` gulp task which has mangling disabled.

### 2. `monaco.d.ts` is out of date

**Symptom:** `Error: monaco.d.ts is no longer up to date. Please run gulp watch and commit the new file.`

**Fix:** Run `yarn compile` first (which regenerates it), then retry the production build.

### 3. `yarn compile` appears to hang

**Symptom:** Sits on `Starting compilation...` for 30+ minutes.

**Context:** This is the TypeScript compilation of ~4000 source files. On first run it may be slow but should not take more than 5-10 minutes. If it's truly stuck, try:

```bash
yarn gulp transpile-client-swc   # faster transpile-only (skips type checking)
```

### 4. Blank window at runtime

**Symptom:** App opens, window appears but is completely white/blank. No menu bar items. Can't Cmd+Q.

**Root cause:** Almost certainly the modified pixi.js was not installed. The Haystack frontend is a React+pixi.js canvas application — without the custom pixi build, the canvas renderer never initialises and nothing renders. There are no console errors because the AMD module loader deadlocks waiting for modules that depend on pixi features that don't exist in stock pixi.js.

**Debug approach:**

```bash
# Run with Chromium verbose logging to see renderer console errors:
VSCODE_DEV=1 ".build/electron/Haystack Editor.app/Contents/MacOS/Electron" . \
  --enable-logging=stderr --v=1 2>&1 | grep "CONSOLE"
```

### 5. IIFE concatenation bug in production build

**Symptom:** `Uncaught TypeError: (intermediate value)(...) is not a function` at workbench.js line ~3297.

**Cause:** `src/bootstrap-window.js` ends with `})` instead of `});`. When the build concatenates bootstrap files, the missing semicolon causes the next IIFE to be parsed as a function call.

**Fix:** Add semicolon to end of `src/bootstrap-window.js`:

```js
  return {
    load,
  }
});  // <-- semicolon required
```

## Architecture Notes

- This is a **VS Code 1.90 fork** with Haystack's canvas UI layered on top
- The canvas UI lives in `src/vs/workbench/browser/haystack-frontend/` (React + zustand + pixi.js)
- Electron version: **29.4.0** (pinned in `build/lib/electron.js`)
- AMD module loader (not ESM) — the `vs/loader.js` resolves all dependencies at runtime
- The `bootstrap-window.js` configures AMD paths for React, zustand, pixi.js, @tanstack etc. pointing to UMD builds in `node_modules/`
- Dev mode loads `workbench-dev.html` (separate script tags); prod mode loads `workbench.html` (concatenated)
- `VSCODE_DEV=1` env var controls dev vs production mode (`isBuilt = !env['VSCODE_DEV']`)

## TODO

- [x] Clone and build `haystackeditor/pixijs`, vendor the dist into this repo
- [x] Update `build-scripts/edit-npm-modules.sh` to use vendored path
- [x] Fix the `bootstrap-window.js` semicolon issue
- [x] Verify dev build runs (`yarn compile` + `./scripts/haystack-editor.sh`)
- [x] Verify production build runs (`build-scripts/build-darwin-arm64.sh`)
- [x] Decide whether to disable mangling permanently or fix the @pixi `.d.ts` issue — keep mangling enabled; deleting `node_modules/@pixi/**/*.d.ts` is sufficient
