# cinny: references

## Sources

- Upstream: `github.com/cinnyapp/cinny` at tag `v<BASE_VERSION>`:
  `Dockerfile` (release build and image), `.github/workflows/prod-deploy.yml`
  (the same build, with `NODE_OPTIONS`), `.node-version`, `.npmrc`,
  `package.json` and `package-lock.json` (install scripts, license),
  `vite.config.js` and `build.config.ts` (output, base path, static
  copies, sourcemaps, Element Call), `docker-nginx.conf` and
  `netlify.toml` (SPA routing), `config.json` (runtime settings),
  `src/sw.ts` (service worker)
- Server: `github.com/static-web-server/static-web-server` at tag
  `v<SWS_VERSION>`: `Cargo.toml` (features, `rust-version`),
  `.cargo/config.toml` (`tokio_unstable`), `.github/workflows/release.yml`
  (its release build), `src/settings/cli.rs` (`SERVER_*` variables),
  `src/fallback_page.rs`, `src/health.rs`, `src/compression_static.rs`,
  `src/security_headers.rs`, `src/signals.rs`
- Docs: https://static-web-server.net/configuration/environment-variables/

## Decisions

- **static-web-server, not nginx:** one static musl binary on `scratch`,
  where nginx needs shared libraries (the `cc-debian13` route of
  `containers/haproxy`) for nothing this app uses. It does what
  `docker-nginx.conf` does: a fallback page for unknown paths
  (`SERVER_FALLBACK_PAGE`), a health endpoint (`SERVER_HEALTH`), env
  configuration, a graceful stop on SIGTERM. Rejected: Caddy (larger,
  admin API), busybox httpd (no fallback with status 200).
- **Built from source, not the release tarball:** the tarball is signed
  with a PGP key upstream prints in its CI logs only: no fingerprint to
  check. The tag's commit is checked by `ADD --checksum`.
- **Two pinned sources** (`base`, `sws`), each with its commit.
- **Default features of the server**, built as its `Cargo.toml` defaults:
  TLS, directory listing, basic auth and metrics are compiled in and
  off at runtime (their `SERVER_*` defaults). Its release workflow adds
  `--features=all`, the experimental tokio metrics: not needed, metrics
  stay off. The C crates (`ring`, `zstd-sys`) are built with `musl-gcc`.
  `cargo auditable` embeds the crate list for the SBOM.
- **Upstream's app paths and settings:** `/app`, `/app/config.json`,
  so its docs apply. Port 8080 (the server's default, above 1024): no
  capability needed, unlike upstream's 80. Not root, a read-only root
  filesystem: the server writes nothing.
- **`SERVER_CACHE_CONTROL_HEADERS=false`:** the server's default gives
  `.js` a year; `sw.js` and `pdf.worker.min.js` have no hash in their
  names and would outlive a release. nginx, upstream's, sends none.
- **Security headers left off:** the set includes
  `X-Frame-Options: DENY` (`src/security_headers.rs`), which blocks
  Element Call, a same-origin iframe (`public/element-call/`). Upstream
  sends none.
- **Missing files answer `index.html`, 200:** the fallback applies to
  every GET 404 (`can_serve`), where nginx and Netlify answer 404 for a
  missing `assets/*` or `public/*`. A stale tab asking for an old chunk
  gets HTML where it would get a 404: it fails to load either way, and
  the service worker (`src/sw.ts`) caches no app file. The smoke test
  pins it.
- **`npm ci --ignore-scripts`:** `canvas` (an optional dependency of
  `pdfjs-dist`, never loaded by the browser bundle) downloads a prebuilt
  binary without a checksum, or builds one; `@swc/core` and `esbuild`
  only check binaries their platform packages ship; `core-js-pure`
  prints a banner; `fsevents` is macOS-only; husky (`prepare`) needs
  `.git`. The build and the test show nothing needs them.
- **Precompressed at build time:** `.br` (Brotli 11) and `.gz` (level 9)
  beside each `css`, `html`, `js`, `json`, `mjs`, `svg` and `wasm` file,
  sent as they are by `compression_static` (`SERVER_COMPRESSION_STATIC=true`:
  off by default) instead of compressing each response, at a better
  ratio. Not `*.map` (devtools
  only, size), not the root `config.json`: the server looks for
  `config.json.br` before the file, so it would hide a mounted
  `config.json`. A variant is kept only when smaller. Node's `zlib`
  does it: no package. The `.br` is the same bytes the test compares.
- **Sourcemaps kept:** upstream ships them (`build.sourcemap: true`);
  fetched by devtools only, and the source is public (AGPL).
- **`node:<version>-trixie-slim`:** upstream's Node major
  (`.node-version`); the digest as `containers/cryptgeon`'s.
- **Built and tested as UID 65532:** install, build and test run
  without root, each in its own copy of the source; caches have ids of
  their own (`npm-cache-65532`, `cargo-registry-65532`,
  `sws-target-65532`).
- **npm packages in the SBOM** (`BUILDKIT_SBOM_SCAN_STAGE` on
  `frontend-files`): the bundle names no package, so scanners saw none.
  The stage holds `node_modules` and the built app only: the `frontend`
  stage would add node's image. Build tools are listed too: npm doesn't
  tell them apart from what the bundle holds.
- **Server test in the build stage:** `scratch` has no shell, so no
  final-stage test beyond `--version`.
- **`SERVER_LOG_LEVEL=info`:** the server's default, `error`, logs no
  request (`/health` probes are logged at debug only: no noise).
- **No CA bundle, no `HEALTHCHECK`:** no outbound TLS, and no curl in the
  image (Kubernetes ignores `HEALTHCHECK`; probe `/health`).
- **Licenses:** the app's `LICENSE` (`AGPL-3.0-only`) and the server's
  `LICENSE-MIT` and `LICENSE-APACHE` (`MIT OR Apache-2.0`).
