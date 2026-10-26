# sable-next

Sable (a Matrix web client) built from source: upstream's static web
app and its Rust core compiled to WebAssembly, served by
static-web-server (SWS), one static musl binary, on `scratch`. The
server side is `containers/cinny`'s: read its `AGENTS.md` before
changing it. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The build is upstream's release build (`.forgejo/actions/setup`):
  `node scripts/build/build-wasm.mjs --release`, `pnpm install
  --frozen-lockfile`, `pnpm exec vite build`. `--ignore-scripts` stays;
  a build that needs a script gets `pnpm rebuild <package>` for that one,
  with its reason in `REFERENCES.md`.
- **Tools follow the source**: wasm-bindgen and wasm-opt are the
  releases `.mise/mise.lock` names, checked against its sha256; Rust is
  the image's (`RUSTUP_TOOLCHAIN`), Node the major of
  `.mise/config.toml`. No version of them in `docker-bake.hcl`.
- **No Sentry DSN**: error reporting stays off and its settings hidden.
- **Headers come from `_headers`**: the build turns `dist/_headers` into
  `sws.toml` and fails on a rule it can't express. Fix the converter,
  never edit the rules by hand. No server-wide `Cache-Control`
  (`service-worker.js` is unhashed), no security headers (upstream
  sends none).
- **Precompressed copies**, never beside the root `config.json`, as
  cinny's.

## Smoke test

The build stage runs it (`scratch` has no shell): `--version`, then the
server with the built app and `sws.toml`, asked for `/health`, `/`
(`no-cache`), a deep link, a page without `.html`, `config.json`
(`no-cache`), the service worker, a bundle (`immutable`) and its Brotli
copy, the core and DeepFilterNet's (`application/wasm`), the manifest,
a missing file (falls back), the request log, and a clean SIGTERM stop.
Files are checked by content type: the fallback answers any path.

## Updates

Renovate follows both GitHub tags, stable releases only. Minor and
patch releases of both, and Node and Rust minor bumps, are automerged
(the smoke test covers files and headers, not a login); a major
release never. Before merging a Sable release read upstream's
`.forgejo/actions/setup/action.yml`, `.forgejo/workflows/tauri-build.yml`
(build-web: its variables), `scripts/build/build-wasm.mjs`,
`vite.config.ts`, `static/_headers`, `packaging/docker/Caddyfile`,
`.mise/config.toml`, `.mise/mise.lock`, `pnpm-workspace.yaml` and
`package.json` at the new tag: a new build variable, a new Node major
or Rust release (`rust-toolchain.toml`), a tool archive's new layout, a
new install script (`allowBuilds`) or pnpm major (`packageManager`), a
new route or header the Caddyfile adds. For SWS, cinny's *Updates*.
