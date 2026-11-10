# bootc images

Bootable OS images, one per `bootc/<name>/`, described by the
`docker-bake.hcl` beside each Containerfile (targets, versions, tags) and
built with BuildKit by `.github/workflows/build-bootc.yml`, or by
`bootc/build.sh` for a disk image. `fedora` and `almalinux` have two
stages (`fedora-coreos` has its own build context, tests and releases:
[fedora-coreos/AGENTS.md](fedora-coreos/AGENTS.md)):

- `base`: the host system, not an image on its own;
- `kubeenv` (`FROM base`): k3s. The one target, tagged
  `<name>:<BASE_VERSION>-v<Kubernetes minor>k3s`.

Before a change, read:

- the image's own `AGENTS.md`, and `bootc/k3s/AGENTS.md` for a
  `kubeenv` stage
- [REFERENCES.md](REFERENCES.md), for sources and the reason behind
  each shared rule: firewalld, signing, disk images
- [K3S.md](K3S.md), the k3s host setup, for `bootc/k3s/` or a
  `kubeenv` stage

## Layout

- **Build context** is `bootc/`, shared: an image can `COPY` another's
  files (`COPY ./fedora/sysroot/common/ /`). Each Containerfile
  has a `Containerfile.dockerignore` beside it that lists what it reads,
  so that a change to another image doesn't rebuild it; fedora-coreos
  builds from its own folder, with its own `.dockerignore`.
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
- `ARG BASE_VERSION` before `FROM` pins the base to a major release and
  is the image's tag. It has no default: the Bake target sets it, from
  a `matrix` entry behind a `# renovate:` comment, which Renovate bumps
  in a PR reviewed by hand. A new base
  fails the build until `sysroot/<BASE_VERSION>/` holds the new base's
  `/etc/containers/policy.json` plus our changes (REFERENCES.md,
  "Signing"). The tag changes: hosts move with `bootc switch`.
- A new image is a `docker-bake.hcl` beside its Containerfile, with its
  own `Containerfile.dockerignore`: `build-bootc.yml` finds it, no
  workflow changes. `docker buildx bake -f docker-bake.hcl -f
  bootc/docker-bake.hcl -f bootc/<name>/docker-bake.hcl --print` lists
  its targets.
- `RUN bootc container lint` is the last instruction of each stage.
- Users and SSH keys go in `config.toml` (repo root, git-ignored,
  template `bootc/config.example.toml`): added to the disk image only,
  and optional: CI's release disks have none.
- `firewall-offline-cmd` removes a service from a zone with
  `--remove-service-from-zone=<service>` (REFERENCES.md, "Firewalld").

## Build check

```sh
bootc/build.sh <id>   # id: a Bake target, e.g. fedora-45; builds it and a qcow2; needs docker buildx and rootful podman
bootc/run.sh <id>     # macOS Apple Silicon, then: ssh -p 2222 <user>@localhost
```

Done when each build ends without error and, for `run.sh`, the SSH login
works.
