# bootc images

Bootable OS images, one per `bootc/<name>/`, built with podman by
`bootc/build.sh` and `.github/workflows/build-bootc.yml`. Every
Containerfile has three stages:

- `base`: the host system, not an image on its own;
- `kubeenv` (`FROM base`): k3s, no Docker. Tag
  `<name>:<BASE_VERSION>-v<Kubernetes minor>k3s`;
- `dockerenv` (`FROM base`): Docker. Last, so the default target: the
  plain `<name>:<BASE_VERSION>` image.

Before a change, read:

- the image's own `AGENTS.md`, and `bootc/k3s/AGENTS.md` for a
  `kubeenv` stage
- [REFERENCES.md](REFERENCES.md), for sources and the reason behind
  each shared rule: firewalld, signing, disk images
- [K3S.md](K3S.md), the k3s host setup, for `bootc/k3s/` or a
  `kubeenv` stage

## Layout

- **Build context** is `bootc/`, shared: an image can `COPY` another's
  files (`COPY ./fedora/sysroot/common/ /`). `bootc/.containerignore`
  covers every image.
- **`sysroot/`** holds an image's files at their path in the image,
  copied with `COPY --link`: `sysroot/common/`, then
  `sysroot/<BASE_VERSION>/` for files that differ between base releases
  (`policy.json`).
- **`bootc/k3s/`** is shared, not an image: every `kubeenv` stage runs
  its `install.sh` and copies its `sysroot/`.

## Rules

- `/usr` holds content and config, `/etc` only machine-local config.
  `/var` ships empty: the `RUN` that installs packages also removes their
  logs, caches and state.
- Configure through drop-in folders (`*.d/`); files packages ship stay
  untouched.
- `ARG BASE_VERSION=<version>` before `FROM` pins the base to a major
  release and is the image's tag. CI passes it from the `build-bootc.yml`
  matrix; Renovate bumps both in one PR, reviewed by hand. A new base
  fails the build until `sysroot/<BASE_VERSION>/` holds the new base's
  `/etc/containers/policy.json` plus our changes (REFERENCES.md,
  "Signing"). The tag changes: hosts move with `bootc switch`.
- A new image joins both `build-bootc.yml` matrices, `hadolint` and
  `build`.
- `RUN bootc container lint` is the last instruction of each stage.
- Users and SSH keys go in `config.toml` (repo root, git-ignored,
  template `bootc/config.example.toml`): added to the disk image only.
- `firewall-offline-cmd` removes a service from a zone with
  `--remove-service-from-zone=<service>` (REFERENCES.md, "Firewalld").

## Build check

```sh
bootc/build.sh <name>   # default target and a qcow2; needs rootful podman and ./config.toml
bootc/run.sh <name>     # macOS Apple Silicon, then: ssh -p 2222 <user>@localhost
podman build --format=docker --target kubeenv -f bootc/<name>/Containerfile -t ghcr.io/spnngl/images/<name>:<BASE_VERSION>-v<Kubernetes minor>k3s bootc/
```

Done when each build ends without error and, for `run.sh`, the SSH login
works.
