# configarr

Configarr (TRaSH-Guides custom formats and quality profiles synced into
Sonarr, Radarr and the other *arr apps; Node.js) built with Dalec from
`spec.yml`: one Debian trixie package (upstream's bundle and the node
binary), installed by the `trixie/container` target into an image built
from its dependency closure. A job: it runs once and exits. Runtime
contract: the spec's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Node.js and pnpm stay at upstream's majors: its `Dockerfile`'s `FROM
  node:` and `corepack prepare pnpm@`.
- Upstream's paths (`/app/config`, `/app/repos`): its docs apply as
  written.

## Tests

The spec's: `dumb-init` running `node` (its version), `git` and its
https transport, then the bundle up to reading the config (configarr's
version). No sync: that needs a live instance. By hand, after a change
to the closure: run the image against a Sonarr container
(`examples/full/` upstream) with `DRY_RUN=true`, `--read-only` and the
volumes of the contract; the summary counts Sonarr's instance as a
success.

## Gotchas

- `/app/repos` must be writable by 65532: Docker creates a new named
  volume owned by root. Clones left by upstream's image, which runs as
  root, too: `chown -R 65532:65532` them.

## Updates

configarr is never automerged. Before merging its PR: compare upstream's
`Dockerfile` (Node and pnpm majors, the `apk add` line: the tools it
runs) and `src/env.ts` (paths) with the spec. A checksum-only update
means upstream moved the tag.

Node.js and pnpm: minor and patch releases are automerged once the
build passes (the node image through `renovate.json5`'s build tools
rule). A major release: merge it only once upstream's `Dockerfile`
moved to it; until then, close the PR (Renovate then ignores that
major). The node image's major PR also bumps the other images on it
(`rg library/node containers`): closing it holds them too. Corepack ships with Node.js up to 24: a newer
node image needs pnpm another way.
