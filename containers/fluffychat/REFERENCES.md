# fluffychat: references

## Sources

- Upstream: `github.com/krille-chan/fluffychat` at tag `v<BASE_VERSION>`:
  `Dockerfile` (image build), `scripts/prepare-web.sh` (the sources it
  fetches and builds), `.github/workflows/main_deploy.yaml` and
  `release.yaml` (the same web build), `.fvmrc` (Flutter),
  `pubspec.yaml` and `pubspec.lock` (packages, `assets/vodozemac/`),
  `lib/config/app_config.dart` (`vodozemacVersion`),
  `lib/config/setting_keys.dart` (`config.json`), `lib/main.dart`
  (vodozemac's path), `config.sample.json`, `web/index.html`, `LICENSE`
- Flutter: `github.com/flutter/flutter` at tag `<FLUTTER_VERSION>`:
  `bin/internal/update_engine_version.sh` and `update_dart_sdk.sh`
  (engine and Dart SDK downloads), `packages/flutter_tools/lib/src/base/bot_detector.dart`
  (`BOT`)
- vodozemac: `github.com/famedly/dart-vodozemac` at tag
  `<VODOZEMAC_VERSION>`: `dart/pubspec.yaml` (`flutter_rust_bridge`),
  `rust/Cargo.lock` (`wasm-bindgen`)
- flutter_rust_bridge, at the version `dart/pubspec.yaml` pins:
  `frb_dart/lib/src/cli/build_web/` (the wasm-pack call, its nightly
  flags, its tool installs), `frb_codegen/src/library/build_web/mod.rs`
  (the codegen wrapper), `frb_dart/lib/src/wasm_module/_web.dart`
  (cross-origin isolation, a warning only)
- wasm-pack: `github.com/wasm-bindgen/wasm-pack` at `v<WASM_PACK_VERSION>`:
  `src/install/mod.rs` (wasm-bindgen from `PATH` at the locked
  version), `src/wasm_opt.rs` (wasm-opt from `PATH`)
- LiveKit: `github.com/livekit/client-sdk-flutter` at tag
  `v<LIVEKIT_VERSION>`: `web/e2ee.*.dart` (the worker and the patched
  lines), `pubspec.lock`
- native_imaging: `github.com/famedly/dart_native_imaging`, release
  `v<NATIVE_IMAGING_VERSION>`: `native_imaging.zip`, built by
  `.github/workflows/publish.yml`
- Server: `github.com/static-web-server/static-web-server` at tag
  `v<SWS_VERSION>`, as `containers/cinny/REFERENCES.md` lists.

## Decisions

- **static-web-server, not nginx:** as `containers/cinny`, one static
  musl binary on `scratch`. Upstream's nginx runs its defaults: no
  fallback, no `Cache-Control`, which the server's settings reproduce;
  the security headers are this image's addition (below).
- **Six pinned sources** (`base`, `flutter`, `vodozemac`, `livekit`,
  `sws` by commit; `native_imaging` by the zip's sha256, Renovate's
  digest of the release file). Upstream's script clones vodozemac and
  LiveKit at a branch and fetches the zip unchecked.
- **Lockstep check and one Renovate group:** the app loads vodozemac
  from `assets/vodozemac/<version>/` (`lib/main.dart`), and each
  package's Dart side is built from `pubspec.lock`'s version, so a
  source at another release than FluffyChat names builds an app that
  breaks at runtime. The check fails the build first; the group
  (`separateMajorMinor: false`, as `flux-aio`) brings the sources in
  with the FluffyChat release that names them.
- **LiveKit at `pubspec.lock`'s tag:** upstream's script clones the
  default branch, whose worker can differ from the `livekit_client`
  package the app talks to. The tag matches it. Upstream's patch
  (PBKDF2 to HKDF, livekit/client-sdk-flutter#974) is applied after
  checking each of its three patterns, and checked again in the
  compiled worker: an `HKDF` key and no `PBKDF2` one. The worker is
  the client side of calls, in the browser: `containers/livekit` (the server,
  `livekit/livekit`, its own versions) has none of it.
- **Stable Rust with `RUSTC_BOOTSTRAP=1`:** flutter_rust_bridge runs
  wasm-pack with `-Z build-std` and the atomics target features
  (threads need a shared memory, built with the standard library).
  The `rust` image Renovate already follows takes them with
  `RUSTC_BOOTSTRAP=1` and `rust-src`; the toolchain name passes as
  `--wasm-pack-rustup-toolchain` where flutter_rust_bridge says
  `nightly`.
- **`dart run flutter_rust_bridge build-web`, no codegen binary:**
  `flutter_rust_bridge_codegen build-web`, upstream's call, only runs
  this command in the Dart root; compiling the codegen crate takes
  minutes for nothing. Its Dart packages have no lock file
  (dart-vodozemac commits none): pub picks the newest matching ones,
  as upstream's build.
- **wasm-pack, wasm-bindgen and wasm-opt installed first:** the build
  installs or downloads each one missing, at its newest or an unchecked
  release. wasm-pack: `cargo install --locked` at its pin (Renovate's
  `crate` datasource, with `versioning=semver`: the crate default,
  cargo's, reads `0.15.0` as the range `^0.15.0` and would never
  propose a patch release); wasm-bindgen-cli: the version vodozemac's
  `Cargo.lock` locks, which wasm-pack requires; wasm-opt: Debian's
  `binaryen`, from the snapshot.
- **Flutter from git with `.git`:** the tool reads its version from the
  tag and its engine's from a tracked file
  (`update_engine_version.sh`), so `ADD --keep-git-dir`. It downloads
  its Dart SDK and engine artifacts by the engine commit, without
  checksums: upstream's way, the commit pinned through Flutter's.
  `BOT=true` turns off its update check and analytics.
- **`pub get --enforce-lockfile`:** FluffyChat's and LiveKit's packages
  at their `pubspec.lock` versions and hashes. LiveKit's with
  `--no-example`: its example app commits no lock file, and the worker
  is built from `web/` alone.
- **Upstream's build flags:** `--dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/`
  (CanvasKit from the image, not Google's CDN), `--release`,
  `--source-maps`. Not the release workflow's `--base-href "/web/"`:
  the image serves the app at `/`, as upstream's.
- **No `config.json`:** upstream's image copies the build context's
  `config.*`: at the tag, `config.sample.json` only, which the app
  never reads (users copy it, see the Containerfile's header). The app
  fetches `config.json` and starts on its defaults when it is missing.
  Users mount theirs.
- **Missing files answer 404:** the app routes in the fragment
  (`GoRouter` without a path URL strategy), so every page loads `/`.
  nginx answers the same.
- **No `Cache-Control`:** as nginx's defaults. `main.dart.js`,
  `flutter.js` and `version.json` have no hash in their names and must
  follow a release.
- **Security headers on, unlike upstream:** SWS's set
  (`src/security_headers.rs`): HSTS (two years, `includeSubDomains`,
  `preload`), `X-Frame-Options: DENY`, `X-Content-Type-Options:
  nosniff`, `Content-Security-Policy: frame-ancestors 'self'`. The app
  embeds no page (no iframe in `lib/` or `web/`; calls are LiveKit's
  SDK, sign-in returns through `auth.html` in a popup), so nothing
  breaks; `containers/cinny` turns them off for Element Call's frame.
  HSTS assumes TLS on the host and its subdomains.
- **Build leftovers removed:** `flutter build web` copies all of `web/`
  and dart2js writes `.deps` files (the build's paths), Flutter a
  `.last_build_id`; no page asks for them, upstream ships them.
  `native_executor.dart` goes too, its compiled `.js` stays. The
  vodozemac folder's `.gitkeep` stays: the asset manifest lists it.
- **No COOP/COEP headers:** vodozemac's module asks for a cross-origin
  isolated page and only warns without one; the headers would block
  media from other origins. Upstream sends none.
- **Precompressed at build time:** as `containers/cinny`, `.br` (Brotli
  11) and `.gz` (level 9) beside each `css`, `html`, `js`, `json`,
  `mjs`, `svg` and `wasm` file, kept when smaller, with Debian's
  `brotli` and `gzip -n`. Not `*.map`.
- **Sourcemaps kept:** upstream builds them; fetched by devtools only,
  and the source is public (AGPL).
- **Dart packages not in the SBOM:** BuildKit's scanner catalogs an
  image's installed packages; syft reads `pubspec.lock` only when
  scanning a directory. The app's bundled packages and their licenses
  are in `/app/assets/NOTICES`. The server's crates are in its binary
  (`cargo auditable`). The WebAssembly modules' sources are missing
  too: vodozemac's crates (the encryption) and native_imaging's build; their
  fixes arrive as releases of dart-vodozemac and native_imaging, which
  Renovate follows.
- **Built and tested as UID 65532:** each source in its own copy, caches
  with ids of their own (`pub-cache-65532`, `cargo-registry-65532`,
  `vodozemac-target-65532`, `sws-target-65532`).
- **Server test in the build stage, `SERVER_LOG_LEVEL=info`, no CA
  bundle, no `HEALTHCHECK`:** as `containers/cinny`.
- **Licenses:** the app's `LICENSE` (`AGPL-3.0-or-later`) and the
  server's `LICENSE-MIT` and `LICENSE-APACHE` (`MIT OR Apache-2.0`).
