# Haystack Editor (Personal Fork)

This is my personal fork of [haystackeditor/haystack-editor](https://github.com/haystackeditor/haystack-editor). I ran into a bunch of issues trying to build the original from source on macOS, so this fork exists to document the fixes and keep a working build around for myself.

For everything about the project itself — what Haystack Editor is, features, contributing, issues, roadmap, license, etc. — refer to the [original repository](https://github.com/haystackeditor/haystack-editor).

## What This Fork Adds

- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** — everything I learned getting Haystack Editor to build on macOS (Apple Silicon), including the required Node/Yarn/Python versions, a fix for missing C++ stdlib headers on recent macOS SDKs, and the critical (previously undocumented) step of building/installing the custom [pixi.js fork](https://github.com/haystackeditor/pixijs) that the canvas renderer depends on.
- **`vendor/pixijs-dist/`** — a vendored copy of the built pixi.js output, so a sibling `../pixijs` checkout is no longer required just to get a working build.
- Assorted small build-script and tooling fixes (`build-scripts/edit-npm-modules.sh`, ESLint/Prettier ignores, lockfile updates) needed to get `yarn install` and the build working on current tooling.
