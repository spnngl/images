# Agent guide

[ARCHITECTURE.md](ARCHITECTURE.md) explains the design and the reason for
each choice. Before a change, read the sections it touches:

- `images/<name>/`: "`images/<name>`", "Design decisions" and "Known
  limits"
- firewall of a bootc image: "Firewalld (bootc images)"
- `.github/workflows/`: "CI: ..." and "Vulnerability scanning"
- `renovate.json5`, or a pinned version: "Updates"
- `policy.json`, signing keys: "Signing"
- `scripts/`: "Disk images" and "Running"

## Sources of truth

Read the source, at the version this repository pins, not blog posts or
memory. An image's upstream is named in its ARCHITECTURE.md section.

- BuildKit (Containerfiles under `docker buildx`):
  `github.com/moby/buildkit` (`frontend/dockerfile/docs`)
- Renovate: `github.com/renovatebot/renovate` (`docs/usage`, managers in
  `lib/modules/manager`, presets in `lib/config/presets/internal`)

## Every image

- One folder per image, `images/<name>/`. The build context is the
  shared `images/` folder, so an image can `COPY` another's files (`COPY
  ./fedora/sysroot/common/ /`); the one `.containerignore` at `images/`
  covers every image. `images/k3s/` is not an image: every `kubeenv`
  stage runs its `install.sh` and copies its `sysroot/`.
- Every pinned version (image tag, release, checksum) is tracked by
  `renovate.json5`: the dockerfile manager reads `FROM` and `# syntax=`;
  anything else needs a custom manager matching every place it is
  written, under one dependency name. Versions are written only where
  Renovate updates them; docs and comments say `<BASE_VERSION>`.
- Credentials come from the runtime: logins from `config.toml`
  (git-ignored, see `config.example.toml`), an application's secrets
  from its environment. Images hold no user, password, key or pull
  secret.
- Containerfiles pass `hadolint` (`.hadolint.yaml`). Ignore a finding
  only with a comment saying why.
- Comment every significant step with *why*, and link docs when useful.

## bootc images

Built with podman by `scripts/build.sh` and
`.github/workflows/build-bootc.yml`. Sources of truth:

- bootc: `github.com/bootc-dev/bootc` (`docs/src`, lint rules in
  `crates/lib/src/lints.rs`)
- Fedora bootc examples: `gitlab.com/fedora/bootc/examples`
- image-builder / bootc-image-builder: `github.com/osbuild/image-builder`
- buildah (Containerfiles under podman): `github.com/containers/buildah`
- Base image tags:
  <https://quay.io/repository/fedora/fedora-bootc?tab=tags>,
  <https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags>,
  <https://quay.io/repository/centos-bootc/centos-bootc?tab=tags>

Rules:

- Files sit in `images/<name>/sysroot/`, at their path in the image,
  copied with `COPY --link`: `sysroot/common/`, then
  `sysroot/<BASE_VERSION>/` for the files that differ between base
  releases (`policy.json`).
- Content and config in `/usr`; `/etc` only for machine-local config;
  `/var` left empty, package manager logs, caches and state removed in
  the same `RUN`.
- Drop-in folders (`*.d/`) rather than edits to files packages ship.
- `ARG BASE_VERSION=<version>` before `FROM` pins the base to a major
  release, and is the image's tag. CI passes it from the
  `build-bootc.yml` matrix; Renovate bumps both in one PR. The build
  fails until `sysroot/<BASE_VERSION>/` holds the new base's
  `/etc/containers/policy.json` plus our changes (ARCHITECTURE.md,
  "Signing").
- A new image is added to `build-bootc.yml`: `paths`, and both
  matrices, `hadolint` and `build`.
- The last instruction is `RUN bootc container lint`.

## Application images

An upstream app run as a container, not a host. `BASE_VERSION` is the
upstream release and the image's tag, written once (CI reads it).
`.github/workflows/build-apps.yml` finds and builds them with `docker
buildx`: no workflow change. `scripts/build.sh` refuses them.

Pick the build by what the app needs at runtime, and name that need:

- One static binary (Go with `CGO_ENABLED=0`, Rust on musl): a
  Containerfile on `scratch`, skill `add-containerfile-image`.
- Distro packages (an interpreter, shared libraries, tools it execs):
  Dalec, skill `add-dalec-image`.

## Scripts

- Bash, `set -euo pipefail`, run from any folder (they `cd` to the repo
  root).
- Must pass `shellcheck`, including SC2250 (`${var}` braces).
- Check requirements first and fail with the command that fixes them.
- Keep them small. Add options only when there is a real need.

## Verifying changes

```sh
scripts/build.sh <name>   # bootc; needs rootful podman and ./config.toml
scripts/run.sh <name>     # macOS Apple Silicon, then: ssh -p 2222 <user>@localhost
docker buildx build -f images/<name>/Containerfile images/   # application image
docker buildx build -f images/<name>/spec.yml --target trixie/container images/   # Dalec image
shellcheck scripts/*.sh
docker run --rm -v "${PWD}:/w:ro" -w /w docker.io/hadolint/hadolint:v2.15.1 hadolint images/*/Containerfile
docker run --rm -v "${PWD}:/w:ro" -w /w ghcr.io/renovatebot/renovate:44.151.2 renovate-config-validator --strict
```

Report each check as run or not run, with its result.

## Commits

Conventional Commits: `<type>(<scope>): <summary>`, with a body explaining
why.
