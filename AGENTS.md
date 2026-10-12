# Agent guide

Read [ARCHITECTURE.md](ARCHITECTURE.md) first. It explains the layout and
the reasons behind the current choices.

## Sources of truth

Check the source rather than blog posts or memory:

- bootc: `github.com/bootc-dev/bootc` (`docs/src`, lint rules in
  `crates/lib/src/lints.rs`)
- Fedora bootc examples: `gitlab.com/fedora/bootc/examples`
- image-builder / bootc-image-builder: `github.com/osbuild/image-builder`
- buildah (Containerfile behaviour under podman): `github.com/containers/buildah`
- firewalld (zone/policy/ipset behaviour): `github.com/firewalld/firewalld`
  (`doc/xml` for docs, `src/firewall/core` for behaviour)
- Dalec (`images/*/spec.yml`): `github.com/project-dalec/dalec`
  (`website/content` for docs, `spec.go` for the schema), at the tag of
  the frontend in the spec's `# syntax=` line
- nushell (`images/almalinux/geoblock.nu`): `github.com/nushell/nushell`,
  at the tag of the `ghcr.io/nushell/nushell` image the Containerfile uses
- Base image tags:
  <https://quay.io/repository/fedora/fedora-bootc?tab=tags>,
  <https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags>
- Garage (`images/garage`): `git.deuxfleurs.fr/Deuxfleurs/garage`
  (`doc/book` for docs, `nix/compile.nix` for the release build), at the
  Containerfile's `BASE_VERSION` tag
- Renovate (`renovate.json5`): `github.com/renovatebot/renovate`
  (`docs/usage`, managers in `lib/modules/manager`, presets in
  `lib/config/presets/internal`)

## Rules for images

- One folder per image: `images/<name>/`, with its own `Containerfile`.
  The build context is the shared `images/` folder (see
  `scripts/build.sh`), not the image's own folder: a `Containerfile` can
  `COPY`/`ADD` another image's files, e.g. `COPY ./fedora/sysroot/common/ /`.
  One `.containerignore` at `images/` covers every image; don't add a
  per-folder copy. `images/k3s/` is not an image: it holds the k3s
  install every `kubeenv` stage runs, and its `sysroot/`, which every
  `kubeenv` stage copies.
- Put files in `images/<name>/sysroot/`, at the path they get in the
  image (for example `images/<name>/sysroot/usr/lib/...`), copied with
  `COPY --link ./<name>/sysroot/ /`. Don't write files inline from `RUN`.
  bootc images split it: `sysroot/common/`, then `sysroot/<BASE_VERSION>/`
  for the files that differ between base releases (`policy.json`),
  copied after it.
- Prefer `/usr` for content and config. Use `/etc` only for config that
  must be machine-local. Never leave files in `/var`: clean up package
  manager logs, caches and state in the same `RUN`.
- Use drop-in folders (`*.d/`) rather than editing files that packages
  ship.
- Never bake users, passwords, SSH keys or pull secrets into images. Login
  credentials go in `config.toml` (git-ignored). See `config.example.toml`.
- Pin the base image to a major release with `ARG BASE_VERSION=<version>`
  before `FROM`. It is also the image's tag. CI passes it from the
  `.github/workflows/build-bootc.yml` matrix: Renovate bumps both in one PR.
  The build fails until `sysroot/<BASE_VERSION>/` exists, with the new
  base's `/etc/containers/policy.json` plus our changes (see
  ARCHITECTURE.md, "Signing").
- Every pinned version (image tag, release, checksum) must be tracked by
  `renovate.json5`: the dockerfile manager reads `FROM` and `# syntax=`;
  anything else needs a custom manager matching every place it is
  written, under one dependency name. Write versions only where Renovate
  updates them: use placeholders (`<BASE_VERSION>`) in comments and docs.
- New bootc image: add it to `build-bootc.yml` too (`paths`, and both
  matrices, `hadolint` and `build`). Application images need no workflow
  change: `build-apps.yml` finds them.
- Must pass `hadolint` (config: `.hadolint.yaml`). Fix findings; ignore
  one only with a comment saying why.
- bootc images: the last instruction must be `RUN bootc container lint`.
  The `/usr`/`/etc`/`/var` and `policy.json` rules above are for bootc
  images only.
- Application images (a binary run as a container, not a host OS, e.g.
  `images/cs-firewall-bouncer/`): static binary on `scratch`, no bootc
  lint; the last instruction is an exec-form smoke test
  (`RUN ["<binary>", ...]`) that needs no capability. `BASE_VERSION` is
  the upstream release, its `ARG` default the only place it is written
  (CI reads it). Built with `docker buildx` by
  `.github/workflows/build-apps.yml`, like Dalec images: the
  Containerfile sets its own `org.opencontainers.image.source` label.
  `scripts/build.sh` refuses them.
- Dalec images (`images/sabnzbd/`): `images/<name>/spec.yml` instead of
  a `Containerfile`, target `trixie/container`, built with `docker
  buildx` by `.github/workflows/build-apps.yml` (it finds every
  `spec.yml`). `args.BASE_VERSION` is the upstream
  release; pin git sources with `checksum`; the spec's `tests` replace
  the smoke test. The Containerfile rules above don't apply.
- Comment every significant step with *why*, and link docs when useful.

## Scripts

- Bash, `set -euo pipefail`, run from any folder (they `cd` to the repo
  root).
- Must pass `shellcheck`, including SC2250 (`${var}` braces).
- Check requirements first and fail with the command that fixes them.
- Keep them small. Add options only when there is a real need.

## Verifying changes

```sh
scripts/build.sh <name>   # needs rootful podman and ./config.toml
scripts/run.sh <name>     # macOS Apple Silicon, then: ssh -p 2222 <user>@localhost
shellcheck scripts/*.sh
podman run --rm -v "${PWD}:/w:ro" -w /w docker.io/hadolint/hadolint:v2.15.1 hadolint images/*/Containerfile
docker buildx build -f images/<name>/spec.yml --target trixie/container images/   # Dalec images
docker run --rm -v "${PWD}:/w:ro" -w /w ghcr.io/renovatebot/renovate:44.151.4 renovate-config-validator --strict
```

If you can't run a build (for example no podman), say so explicitly
instead of claiming it works.

## Commits

Conventional Commits: `<type>(<scope>): <summary>`, with a body explaining
why. Never commit `config.toml`, `output/` or disk images (`.gitignore`
covers them).
