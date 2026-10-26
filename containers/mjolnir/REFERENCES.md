# mjolnir: references

## Sources

- Upstream: `github.com/matrix-org/mjolnir` at tag `v<BASE_VERSION>`:
  `Dockerfile` and `mjolnir-entrypoint.sh` (release build and image),
  `package.json` (`engines`, `build` and `postbuild` scripts, license),
  `yarn.lock`, `docs/setup_docker.md`, `src/config.ts` (defaults:
  `dataPath`, `health`, `web`; `--mjolnir-config`), `src/index.ts`
  (start, crypto store, the setup error),
  `src/protections/NsfwProtection.ts` (tfjs-node, nsfwjs)
- `@tensorflow/tfjs-node` at `yarn.lock`'s version (npm package):
  `scripts/install.js`, `scripts/deps-constants.js` (libtensorflow URLs),
  `binding.gyp` (headers, rpath), `package.json` (`binary`)
- `github.com/matrix-org/matrix-rust-sdk-crypto-nodejs` at `yarn.lock`'s
  version: `download-lib.js` (the release asset), `index.js` (where it
  loads the addon)
- Base images: `docker.io/library/node` (`22.23-trixie`) and
  `gcr.io/distroless/nodejs22-debian13`
  (`github.com/GoogleContainerTools/distroless`, `nodejs/`)

## Decisions

- **Containerfile on distroless `nodejs22-debian13`, not Dalec or DHI:**
  trixie's `nodejs` is older than `engines.node`; DHI images are
  local-only. libtensorflow and the crypto addon need only distroless'
  libc and libstdc++ (the final `RUN` loads them).
- **Built by `node:22.23-trixie`, the full image:** `node-gyp` needs
  `python3`, `make` and `g++`. Debian trixie, as the final image's libc.
  Its yarn 1 reads upstream's v1 lockfile, as upstream's `node:22-slim`
  does.
- **Built from source:** upstream publishes no build but its image; the
  tag's commit is checked by `ADD --checksum`.
- **`yarn install --ignore-scripts`:** three packages have install
  scripts. `@matrix-org/matrix-sdk-crypto-nodejs`' downloads its addon
  from GitHub, `@tensorflow/tfjs-node`'s libtensorflow from Google's
  storage and a prebuilt binding (amd64 only), all without a checksum;
  `core-js`' prints a banner.
- **Both addons required:** the bot-sdk loads the crypto addon on import
  (and pins it, exactly 0.4.0); `ProtectionManager` imports
  `NsfwProtection`, which imports tfjs-node: the bot does not start
  without them, the NSFW protection enabled or not. nsfwjs bundles its
  model (MobileNetV2): nothing is downloaded at run time.
- **libtensorflow pinned, per platform, by its sha256:** the archive
  tfjs-node's script fetches: TensorFlow's CPU build on amd64, a build of
  tfjs' (`tf-builds`, r2.7) on arm64. Google publishes no checksum: the
  pins are the archives' sha256. Their versions follow tfjs-node's
  scripts, not a release feed: no Renovate entry; the pin check compares
  them to the scripts.
- **tfjs-node's binding built from source:** its prebuilt binding exists
  for amd64 only. Built as its `build-addon-from-source` script does
  (`node-pre-gyp install --build-from-source`), by npm's `node-gyp`,
  against the image's Node headers (`--nodedir`) and libtensorflow
  unpacked in `deps/`, where `binding.gyp`'s rpath
  (`$ORIGIN/../../deps/lib`) finds it. The headers and `build/` are
  removed.
- **The crypto addon prebuilt, not built from Rust:** the release asset
  its script would fetch, upstream's build, checked by its sha256 (the
  digest GitHub shows). Building it needs Rust and napi-rs at the tag.
- **Pins checked against upstream, Renovate on the addons:** upstream's
  `yarn.lock` is the set it tests, and the bot-sdk pins the crypto
  addon: the image follows it, the build fails on a difference. Renovate
  lists the addons' new releases on the Dependency Dashboard, a PR only
  on approval (`renovate.json5`): it is red until upstream takes the
  release, which for the crypto addon waits on the bot-sdk.
- **A production tree of its own (`/app`):** `yarn install --production`
  in a fresh folder; upstream ships its dev packages (TypeScript,
  mocha, …), the bot runs without them. The addons go in after, so the
  install does not drop them.
- **Source maps dropped:** 200 MB, mostly the dependencies'; Node reads
  them only with `--enable-source-maps`.
- **No SIGTERM handling:** neither Mjolnir nor Node, PID 1, stops on
  SIGTERM, in upstream's image too. Documented in the header (an init,
  or the kill at the stop timeout) rather than a handler of the image's
  own.
- **Upstream's paths:** `/mjolnir`, `/data`, `NODE_CONFIG_DIR=/data/config`,
  `NODE_ENV=production`, default `dataPath` `/data/storage`: its docs
  apply. `node_modules` is in `/mjolnir`, not `/`: Node finds it either
  way.
- **Shell-less start:** `ENTRYPOINT ["/nodejs/bin/node",
  "/mjolnir/index.js"]`, upstream's `bot` command. Upstream's `docker
  run … bot --mjolnir-config <file>` works: the bot reads the flag
  anywhere in its arguments and ignores `bot`.
- **No `EXPOSE`:** every port is off in upstream's defaults (the header
  lists them).
- **`app-files` stage:** root owns the app, 65532 the volume's folder;
  the SBOM scans it, not the build stage with node's image.
- **Automerge (`depType=automerge`):** CI starts the bot on an empty
  state; an upgrade of an existing one, and a homeserver, are not
  tested.
- **Built and tested as UID 65532:** install, build and test run without
  root, in their own copy of the source; the cache id is
  `yarn-cache-65532`.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probe `/healthz`.
- **License:** `Apache-2.0` (`package.json`, `LICENSE`).
