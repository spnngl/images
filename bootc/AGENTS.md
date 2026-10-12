# bootc images

Bootable OS images, one per `bootc/<name>/`, built with podman by
`bootc/build.sh` and `.github/workflows/build-bootc.yml`.

Read before a change, in ARCHITECTURE.md:

- the firewall: "Firewalld (bootc images)"
- `policy.json`, signing keys: "Signing"
- `bootc/build.sh`, `bootc/run.sh`: "Disk images" and "Running"

and [K3S.md](../K3S.md) for `bootc/k3s/` or a `kubeenv` stage.

## Sources of truth

- bootc: `github.com/bootc-dev/bootc` (`docs/src`, lint rules in
  `crates/lib/src/lints.rs`)
- Fedora bootc examples: `gitlab.com/fedora/bootc/examples`
- image-builder: `github.com/osbuild/image-builder`
- buildah, which runs the Containerfiles: `github.com/containers/buildah`
- base image tags:
  <https://quay.io/repository/fedora/fedora-bootc?tab=tags>,
  <https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags>,
  <https://quay.io/repository/centos-bootc/centos-bootc?tab=tags>

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
- Configure through drop-in folders (`*.d/`), leaving files packages
  ship untouched.
- `ARG BASE_VERSION=<version>` before `FROM` pins the base to a major
  release and is the image's tag. CI passes it from the `build-bootc.yml`
  matrix; Renovate bumps both in one PR. A new base fails the build until
  `sysroot/<BASE_VERSION>/` holds the new base's
  `/etc/containers/policy.json` plus our changes ("Signing").
- A new image joins both `build-bootc.yml` matrices, `hadolint` and
  `build`.
- The last instruction is `RUN bootc container lint`.
- Users and SSH keys go in `config.toml` (repo root, git-ignored,
  template `bootc/config.example.toml`): added to the disk image only.

## Build check

```sh
bootc/build.sh <name>   # needs rootful podman and ./config.toml
bootc/run.sh <name>     # macOS Apple Silicon, then: ssh -p 2222 <user>@localhost
```
