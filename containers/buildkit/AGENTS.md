# buildkit

BuildKit, rootless: `buildkitd` under RootlessKit with runc, `buildctl`
and git for git sources, built from source as static binaries on this
repository's git image. For Kubernetes pods and CI jobs that build
images without root. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **`FROM` the git image, a shell included:** buildkitd execs `git`, and
  `git submodule` is a shell script. Every other program is built here.
- **Every program static:** the build stage fails on an ELF file with an
  interpreter or a `NEEDED` library; the git image has no C library
  besides what the programs carry. `runc` and `newuidmap` need cgo and
  Alpine's `*-static` libraries (libseccomp, libcap); the rest is CGO
  off.
- **`newuidmap` and `newgidmap` setuid root, built with libcap:** both
  facts matter. Without the setuid bit RootlessKit can't map the id
  range; without libcap (shadow 4.19+), the kernel refuses the write in a
  container with default capabilities. The `-all-static` and `LIBCAP`
  make arguments are not optional (the Containerfile says why).
- **`USER` is `nonroot` in the image's environment:** buildkitd reads it,
  not the UID, to tell it runs rootless, and only then uses the state,
  socket and configuration paths of the user; the `XDG_*` variables
  point them at `/var/lib`, `/run/user/65532` and `/etc`.
- **The versions of runc and RootlessKit follow upstream's
  Dockerfile (`RUNC_VERSION`, `ROOTLESSKIT_VERSION`):** after a BuildKit
  update, compare; a newer one is fine when the smoke test passes. A
  runc build that needs libpathrs (runc 1.6) fails: the Containerfile
  builds without it.
- **The smoke test needs `security.insecure`:** the Containerfile's last
  step runs a daemon. The bake target's `entitlements` is read by
  `.github/workflows/build-apps.yml`; locally:
  `docker buildx create --driver docker-container --buildkitd-flags
  '--allow-insecure-entitlement security.insecure'`, then `docker buildx
  bake --allow security.insecure`.
- **The smoke test can't prove the setuid helper:** the insecure `RUN`
  holds capabilities a container doesn't. Verify a change near it with
  the `docker run` of the check below.
- **Done when** the build passes (the build stage checks every program
  is static and the versions; the final stage starts a daemon and builds
  an image from a git source with a submodule, with a `RUN` as root and
  one as another user) and, by hand, a container with default
  capabilities and the three `unconfined` options of the header shows
  `buildctl debug workers` (`docker exec`) and builds an image.

## Updates

All four sources automerge when the build passes. A checksum-only update
means upstream moved the tag. A BuildKit update that raises Go's
version needs a newer `golang` image: Renovate moves its digest; a new
Alpine branch (3.25) may rename a package, the build fails on it. The
git base follows `containers/git`'s releases.
