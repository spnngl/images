# seerr: references

## Sources

- Upstream: `github.com/seerr-team/seerr` at tag `v<BASE_VERSION>`:
  `Dockerfile` (release build and image), `package.json` (`engines`,
  `packageManager`, lifecycle scripts, `pnpm.onlyBuiltDependencies`,
  `pnpm.overrides`, license), `pnpm-lock.yaml`, `.npmrc`
  (`engine-strict`), `next.config.ts`, `server/index.ts` (`PORT`,
  `HOST`, the paths of `dist/`), `server/utils/appVersion.ts`
  (`committag.json`), `server/utils/appDataVolume.ts` (the `DOCKER`
  marker), `server/datasource.ts` and `server/lib/settings/index.ts`
  (config folder, database), `server/routes/index.ts` (`/api/v1/status`)
- Base images: `docker.io/library/node` (`22.23-trixie`) and
  `gcr.io/distroless/nodejs22-debian13`
  (`github.com/GoogleContainerTools/distroless`, `nodejs/`)

## Decisions

- **Node.js, not Bun:** upstream's contract is Node (`engines.node`,
  enforced by `engine-strict=true`) and pnpm (`only-allow pnpm`,
  `pnpm-lock.yaml`). `bun install` would resolve again: the versions
  and hashes would be Bun's, not the lockfile's. The runtime is three
  Node-API addons (`bcrypt`, `sqlite3`, `sharp`) and a Next.js custom
  server, where Bun's own compatibility table
  (`docs/runtime/nodejs-compat.mdx`) lists gaps (`node:v8`,
  `http.Server`, `perf_hooks`); upstream tests on Node only. `bun build
  --compile` gains nothing: Next reads `.next/` and the addons load
  `.node` files from disk. Revisit when upstream adopts Bun.
- **Containerfile on distroless `nodejs22-debian13`, not Dalec or DHI:**
  trixie's `nodejs` is older than `engines.node`; DHI images are
  local-only. The final image holds distroless' Node, libc, libstdc++,
  CA bundle and tzdata; `sharp` ships its libvips and `sqlite3` bundles
  SQLite.
- **Built by `node:22.23-trixie`, the full image:** `node-gyp` needs
  `python3`, `make` and `g++`. Debian trixie, as the final image's libc.
  The Node of the two images are two pins of one major: the addons use
  Node-API, stable across releases. A major bump changes both by hand;
  Node 25 has no corepack: install pnpm another way then.
- **Built from source, not a release tarball:** upstream publishes
  none; the tag's commit is checked by `ADD --checksum`.
- **`pnpm install --ignore-scripts`, `sqlite3` rebuilt:** `sqlite3`'s
  script (`prebuild-install || node-gyp rebuild`) downloads a binary
  from GitHub without a checksum. It is built from its npm package's
  source, against the image's Node headers (`--nodedir`), by npm's
  `node-gyp`: the 8.4.1 upstream's `pnpm.overrides` pins for it needs
  `distutils`, which Python 3.13 (trixie) dropped. `bcrypt` ships
  prebuilds in its npm package (`node-gyp-build`); `sharp`'s binaries
  come in `@img/sharp-*` packages; `@swc/core`'s and `cypress`' scripts
  fetch or check binaries the build and the server don't use
  (`CYPRESS_INSTALL_BINARY=0`); `prepare` (husky) needs `.git`.
- **Runtime packages only, musl builds removed:** `pnpm prune --prod`,
  then the folders upstream's Dockerfile removes (`ace-builds` sources,
  `country-flag-icons` `1x1`, `react` and `string`, `@heroicons/react/16`:
  the browser bundles hold what the app uses), and the `*musl*` native
  packages: pnpm installs both libc variants, upstream removes the other
  half (`linux-x64-gnu`) for Alpine. The test runs on the result.
- **`next.config.ts` shipped, `tsconfig.json` not:** Next compiles and
  reads `next.config.ts` at start, even with a custom server; without
  it, `/_next/image` answers 400 for upstream's hosts (`remotePatterns`).
  The test checks it. Next needs no `tsconfig.json` to do so (the test
  removes it before starting).
- **`committag.json` with the tag's commit, `COMMIT_TAG` at build:**
  as upstream's Dockerfile does; the app shows it (`/api/v1/status`).
- **Upstream's paths:** `/app`, `/app/config`, port 5055: its docs
  apply. `/app/config/DOCKER` is upstream's marker (`appDataStatus()`):
  the UI warns while no volume is mounted there; a named volume copies
  it in the first time. `/app/.next/cache` is Next's optimized images:
  a volume of its own (a tmpfs fits), so the root filesystem stays
  read-only. The app does not create `config/db`: the image does.
- **Shell-less start:** `ENTRYPOINT ["/nodejs/bin/node"]`, `CMD
  ["dist/index.js"]`: upstream's `npm start` is `NODE_ENV=production
  node dist/index.js`; `NODE_ENV` is an `ENV`. `NEXT_TELEMETRY_DISABLED=1`
  as the `postinstall` script's `next telemetry disable`.
- **`app-files` stage:** root owns the app, 65532 the volumes; the SBOM
  scans it, not the build stage with node's image. `.next/cache` is
  copied first and left out of the `.next` copy: the later layer decides
  the ownership of `/app/.next`.
- **Automerge (`depType=automerge`):** CI exercises the server on an
  empty database; an upgrade of an existing one is not tested. Reading
  the release notes for migrations is the reviewer's, as the
  `AGENTS.md` says.
- **Built and tested as UID 65532:** install, build and test run without
  root, in their own copy of the source; the cache id is
  `pnpm-store-65532`.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probe
  `/api/v1/status/appdata` (`server/routes/index.ts`), not
  `/api/v1/status`: it queries GitHub without a timeout
  (`server/api/github.ts`) and hangs when egress is blocked.
- **Corepack:** pnpm comes from the registry at the version of
  `packageManager` (no hash upstream): corepack checks the registry's
  signature of the package.
- **License:** `MIT` (`package.json`, `LICENSE`).
