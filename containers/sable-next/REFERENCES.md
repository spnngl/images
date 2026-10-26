# sable-next: references

## Sources

- Upstream: `github.com/SableClient/sable-next` at tag `v<BASE_VERSION>`
  (its forge is `git.sable.moe`, GitHub its mirror):
  `.forgejo/actions/setup/action.yml` (the release build),
  `.forgejo/workflows/tauri-build.yml` (`build-web`: its variables),
  `scripts/build/build-wasm.mjs` (the WebAssembly build),
  `scripts/build/fetch-deepfilternet.mjs` (downloaded assets),
  `vite.config.ts` (adapter, fallback, sourcemaps, Sentry),
  `.mise/config.toml` and `.mise/mise.lock` (tools),
  `rust-toolchain.toml`, `Cargo.toml` (`wasm-release` profile),
  `package.json`, `pnpm-workspace.yaml` (`allowBuilds`),
  `static/_headers` and `static/config.json` (runtime settings),
  `packaging/docker/Dockerfile` and `Caddyfile` (upstream's image)
- Server: as `containers/cinny/REFERENCES.md`, plus
  `src/custom_headers.rs` and `src/settings/mod.rs` (header globs,
  `Glob::new`), `src/settings/cli.rs` (`SERVER_CONFIG_FILE`)
- `_headers` format: https://developers.cloudflare.com/pages/configuration/headers/

## Decisions

- **static-web-server, not Caddy:** upstream's image runs Caddy on
  Alpine; SWS is one static binary on `scratch`, as `containers/cinny`
  (its reasons). It does what the Caddyfile does: `/x` finds `/x.html`,
  unknown paths answer `index.html` (200), the `_headers` rules, the
  manifest's `application/manifest+json` (its MIME table). Caddy's
  `encode zstd gzip` becomes precompressed Brotli and gzip.
- **Built in the image, not copied:** upstream's Dockerfile copies a
  `dist` built outside it, so its image proves nothing about the source.
  Here the tag's commit is checked by `ADD --checksum`, then built.
- **Headers from `_headers`:** upstream writes its rules once, for
  Cloudflare (`_headers`) and by hand again in the Caddyfile. The
  build converts `dist/_headers` to SWS' `[[advanced.headers]]`: a
  rule upstream adds (its `main` adds a CSP there) needs no change
  here. SWS compiles a header source with `Glob::new`, where `*`
  crosses `/`, as `_headers`' splat does; placeholders, `!` and
  absolute URLs fail the build. `/` is matched as `/index.html`
  (`custom_headers.rs`). `_headers` stays in `/app`, as in upstream's
  image.
- **Tools from `.mise/mise.lock`:** upstream's build script needs
  `wasm-bindgen` (Cargo.lock's version, it checks) and binaryen's
  `wasm-opt`; mise's lockfile names each release archive per platform
  with its sha256. Taken from there, they are upstream's exact tools
  and move with the source. Rejected: binaryen built from a pinned tag,
  with a check against upstream's version: the binaryen PR fails until
  a Sable release asks for it, and that Sable PR fails until the
  binaryen PR merges, so neither automerges.
- **`RUSTUP_TOOLCHAIN`:** the Rust image's toolchain, not
  `rust-toolchain.toml`'s (clippy, rustfmt, an exact patch release
  downloaded at build time), as `containers/tuwunel`.
- **Node from the `node` stage in the wasm stage:** upstream's script
  is Node (`WebAssembly.compile` checks the output). One binary copied
  from the pinned image, no second pin.
- **No Sentry DSN:** upstream's forks build without one (the
  `build-web` job's comment): reporting is off, its settings hidden, no
  source map upload. `VITE_APP_VERSION=<BASE_VERSION>`,
  `SABLE_BUILD_FLAVOR=stable` and `VITE_SENTRY_ENVIRONMENT=production`,
  as its stable releases; without a DSN the last only names Sentry's
  environment and makes the sourcemaps `hidden`.
- **Sourcemaps deleted:** `hidden` writes them without a
  `sourceMappingURL` in the bundle; they serve devtools only and were
  29 MB, 15% of the image. Upstream's `main` skips them with
  `SABLE_FOSS=1`; the deletion covers both.
- **`pnpm install --ignore-scripts`:** the builds `allowBuilds`
  permits are for the desktop app or the CLIs of other jobs (electron,
  `@sentry/cli`, workerd); esbuild and lightningcss ship their binaries
  in platform packages. `prepare` runs `svelte-kit sync`, which `vite
  build` runs itself, and installs git hooks. The build and the test
  show nothing needs them.
- **DeepFilterNet downloaded by the build:** `vite build` fetches two
  assets and checks their sha256 (`fetch-deepfilternet.mjs`): upstream
  pins them, so no pin here.
- **Rust caches:** `cargo-registry-65532` and `cargo-git-65532`
  (matrix-sdk is a git dependency) are shared; the target,
  `sable-next-target-65532`, is the image's. SWS' target is cinny's,
  `sws-target-65532`: the same source.
- **npm packages in the SBOM** (`BUILDKIT_SBOM_SCAN_STAGE` on
  `frontend-files`), as cinny. The crates compiled into the
  WebAssembly are not listed: no scanner reads a `.wasm`.
- **Licenses:** the app's `LICENSE` (`AGPL-3.0-or-later`) and the
  server's `LICENSE-MIT` and `LICENSE-APACHE` (`MIT OR Apache-2.0`).
