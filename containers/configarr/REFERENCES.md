# configarr: references

## Sources

- Upstream: `github.com/raydak-labs/configarr` at tag `v<BASE_VERSION>`
  (`Dockerfile`, `esbuild.ts`, `src/env.ts`, `src/index.ts`,
  `src/util.ts`); docs <https://configarr.de>
- Node.js: the `docker.io/library/node` image
  (`github.com/nodejs/docker-node`)
- Dalec: `github.com/project-dalec/dalec`, docs
  <https://project-dalec.github.io/dalec/>

## Decisions

- **Dalec:** configarr needs an interpreter (Node.js) and execs a tool
  (`git`).
- **Built from source, as upstream's `Dockerfile`:** `pnpm install
  --frozen-lockfile`, then `pnpm run build` (`tsx esbuild.ts`): one file,
  `bundle.cjs`, every module in it. Not upstream's release binaries
  (`bun build --compile`): prebuilt, and they still need `git`.
- **Node.js from the node image, at upstream's major:** trixie's
  `nodejs` is older. Its `node` binary links only `libstdc++`, `libgcc_s`
  and glibc (OpenSSL and its CA store are built in): the runtime
  dependencies. Its `/usr/local/LICENSE` ships with it. Debian's
  security updates don't reach it: Node's patch releases come through
  Renovate alone, hence automerged.
- **Modules from npm in the build's sandbox network step:**
  `pnpm-lock.yaml`, upstream's, pins each one by hash. Not Dalec's
  `nodemod` generator: it runs `npm install`, which ignores
  `pnpm-lock.yaml`. pnpm through the image's corepack, at the version of
  `docker-bake.hcl`, checked against npm's signing keys (as
  `containers/silo-server`).
- **`CONFIGARR_VERSION` at build time:** `esbuild.ts` writes it into the
  bundle; unset, configarr logs `dev`.
- **`dumb-init` as PID 1, as upstream:** node as PID 1 installs no
  `SIGTERM`/`SIGINT` handler, and the kernel drops unhandled signals to
  PID 1: `docker stop` would wait its timeout, Ctrl-C do nothing.
  `dumb-init` forwards them and reaps git's processes.
- **git with `ca-certificates`:** `simple-git` execs `git` (`clone
  --filter=blob:none`, `sparse-checkout`, `checkout`) over https.
  trixie's `git` only recommends the CA bundle. It brings perl, about
  half the image.
- **`safe.directory=*`, as upstream** (issues #240, #241): git refuses a
  repository its user doesn't own, and a reused `/app/repos` can hold
  clones of another UID, writable through their group. Through
  `GIT_CONFIG_*` in the environment: no gitconfig to ship.
- **Upstream's paths:** `/app` the working directory and `ROOT_PATH`,
  so its docs apply. Volumes `/app/config` and `/app/repos` only: Docker
  gives each declared volume an anonymous one when not mounted, and
  `/app/cfs`, `/app/templates` are optional. `HOME=/app/repos`: no passwd
  entry. The image can't own `/app/repos`: Dalec creates directories
  under `/etc` and `/var/lib` only (`artifacts.go`, `debroot.go`).
- **`AGPL-3.0-only`:** `LICENSE` is the AGPL v3 text, with no "or any
  later version" notice. `package.json`'s `ISC` is npm's default, not
  upstream's choice.
- **Smoke test with `--unhandled-rejections=warn`:** configarr has no
  `--version`; it logs its version, then fails without a config, an
  unhandled rejection that exits 1. As a warning the step exits 0, and
  the failure proves the whole bundle loaded.
- **Node's major not held by a Renovate rule:** majors are never
  automerged, and the node image's dependency is shared with other
  images; *Updates* in `AGENTS.md` says when to merge one.
