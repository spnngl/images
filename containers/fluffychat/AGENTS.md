# fluffychat

FluffyChat (a Matrix client) built from source: upstream's Flutter web
app, served by static-web-server (SWS), one static musl binary, on
`scratch`. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Upstream's build**: the app is what upstream's `Dockerfile` and
  `scripts/prepare-web.sh` produce, step for step: vodozemac compiled
  to WebAssembly, the native executor's worker, native_imaging's
  files, LiveKit's encryption worker with upstream's patch, then
  `flutter build web` with upstream's flags.
- **Lockstep**: each pinned source (Flutter, vodozemac,
  native_imaging, LiveKit) is the release FluffyChat names, in
  `.fvmrc` or `pubspec.lock`; the `web` stage's first `RUN` checks it.
  A new source the script fetches gets its own pin, its `ADD
  --checksum`, its lockstep check and its place in the `fluffychat`
  group of `renovate.json5`.
- A tool the build would fetch at its newest release is installed
  first, pinned: wasm-pack in the bake file, wasm-bindgen at
  vodozemac's `Cargo.lock` version, wasm-opt from the Debian snapshot.
  The accepted exceptions are in `REFERENCES.md`.
- Rust is the stable `rust` image with `RUSTC_BOOTSTRAP=1`, for
  vodozemac's nightly flags.
- The server is built with its default features, static, as UID 65532
  (cache ids end in `-65532`).
- **No `Cache-Control`**: `main.dart.js`, `flutter.js` and the other
  unhashed files must follow a release.
- **Security headers on** (`SERVER_SECURITY_HEADERS`): the app frames
  nothing. A feature that embeds a page (a widget, Element Call) needs
  them reviewed first.
- `/app` holds what a page can ask for: build leftovers (`.deps`,
  `.last_build_id`, Dart sources) are removed after the build.
- **Precompressed copies**: `.br` and `.gz` beside each text asset,
  sent as they are (`SERVER_COMPRESSION_STATIC`). A file users mount
  over gets none, or its stale copy would be served: the image ships
  no `config.json`; a new one is excluded from the `find` that writes
  them, with a check that its copies are absent.

## Smoke test

The build stage runs it (`scratch` has no shell): `--version`, then the
server with the built app, asked for the files `index.html` and the app
load at start, the WebAssembly modules' type, a Brotli copy, the
security headers, a missing `config.json` and file (404), the request
log, and a clean SIGTERM stop. A file upstream adds to the start gets
its request here.

## Updates

Renovate follows each pinned release, stable only: FluffyChat and the
sources it names in one `fluffychat` PR, wasm-pack and SWS each in
their own. The `fluffychat` PR is red while a source has a release
FluffyChat doesn't name yet, and waits for FluffyChat's next release.
When that release names an older one than Renovate proposes, set it on
the PR branch: the version FluffyChat names and its tag's commit (or
the zip's sha256). Minor and patch releases are automerged once green
(the smoke test covers the files and headers, not a login); a major
release is merged by hand.

Before merging a FluffyChat release, diff upstream's `Dockerfile`,
`scripts/prepare-web.sh` and `.github/workflows/` (the web build) with
the last tag. The review is done when each change there is in the
Containerfile, or in `REFERENCES.md` with the reason it is left out.
For SWS, read its `CHANGELOG.md` for changed `SERVER_*` variables.
