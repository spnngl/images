---
name: add-containerfile-image
description: Containerfile application image, a static binary (Go, Rust) on scratch. Use when adding one, or editing a containers/*/Containerfile.
---

# Add a Containerfile image

Shared rules, versions and the build check: `containers/AGENTS.md`.

`containers/garage/` (Rust) and `containers/minio/` (Go) are the **reference
images**: their comments carry the reason for each convention below. Read
the one in your language whole, and copy its shape, with its `AGENTS.md`
and `REFERENCES.md`. `containers/cs-firewall-bouncer/` is no model: root
with `NET_ADMIN`, source not pinned to a commit.

The final image is `scratch`: the binary, and only the files the
Containerfile copies. It is shell-less, so the server test runs in the
build stage.

## Steps

### 1. Map upstream

Clone upstream at the release tag (`git_clone`) and answer each item from
its source, with the file that says so:

- its release build: flags, features, ldflags, and how it sets the
  version `--version` prints (from git, a variable, a file)
- the tag's commit (`git rev-parse <tag>^{commit}`)
- static: no cgo, or musl; it execs nothing (otherwise: Dalec)
- every path it writes, and the flag or variable that moves it onto a
  volume
- listen ports; whether it needs root
- outbound TLS (needs the CA bundle)
- license, as an SPDX id, and the notice files to ship
- a health endpoint, and the smallest real operation through its API

Done when every item has an answer and a source file.

### 2. Write `containers/<name>/Containerfile`

- **Header comment**: what the image is, how it differs from upstream's,
  and the runtime contract: UID/GID, volumes, ports, required env or
  secrets, hardening it runs with (`--read-only`, no capability,
  `no-new-privileges`).
- **Versions**: stage `ARG BASE_VERSION`, `BASE_CHECKSUM`,
  `DEBIAN_CODENAME` (and `DEBIAN_SNAPSHOT_VERSION` if it installs
  packages), set by Bake (step 3). Copy garage's first `RUN`: it checks
  the base's release and installs packages from the snapshot.
- **Build stage**: the toolchain's official image on Debian trixie with
  its digest (`golang:<minor>-trixie@sha256:...`, `rust:<minor>-trixie`;
  the tag's default Debian moves); its `ca-certificates` is the bundle the
  final image copies. Order: `ARG`, `ENV`, then
  `SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]`, after the stage's last
  `ENV` or `ARG`: hadolint 2.15.1 checks the `RUN`s after either as
  `/bin/sh`.
- **Source**, as root: `ADD --link --checksum=${BASE_CHECKSUM} <git
  url>#v${BASE_VERSION} /src`, so a moved tag fails the build.
  `--keep-git-dir=true` only when the build reads git, with `git config
  --system --add safe.directory /src`: git refuses a repository another
  user owns.
- **Build as the image's user**: root-only steps (packages, toolchain
  targets) first, then `USER 65532:65532`, `WORKDIR /out` (created owned
  by that user), `WORKDIR /src`. No passwd entry: set `HOME` (`/tmp`) or
  the tool's own variables. Cache mounts with ids of their own,
  `id=<cache>-65532,uid=65532,gid=65532`: a cache keeps the owner it was
  created with, and root's are shared.
- **Upstream's release build**, static, its version set as upstream's
  release sets it.
- **Server test**, a build-stage `RUN`: `--version` output checked for
  `${BASE_VERSION}`; the server started in the background on `127.0.0.1`
  with random throwaway credentials; `curl --retry-connrefused` on the
  health endpoint; one object written and read back through the API
  (`curl --aws-sigv4` for S3); `kill` and `wait` (`# hadolint
  ignore=DL3001`); temp files removed. Renovate automerges toolchain
  bumps on this test.
- **State folders**, 65532's: a new named volume takes their owner. At
  the root (`/data`): created in the build stage, copied
  `--chown=65532:65532`. Deeper (`/var/lib/<name>`): created while root
  under `/rootfs`, the parents root's and the folder `install -d -o 65532
  -g 65532`, copied `COPY --from=build /rootfs/ /`: `--chown` gives the
  parents it creates to the user too.
- **Final stage**: `FROM scratch`, `ARG BASE_VERSION`, labels
  `org.opencontainers.image.{version,licenses,source}` (source
  `https://github.com/spnngl/images`, `# hadolint ignore=DL3050` with its
  reason). `COPY --link`: the binary `--chown=0:0` (a `COPY` keeps the
  build user as owner; root's, the app can't rewrite it), the CA bundle
  when it makes outbound TLS, the license and notices in
  `/usr/share/doc/<name>/`.
- **Runtime**: `USER 65532:65532`. `ENV` for settings that must survive a
  replaced `CMD`. `EXPOSE`, `VOLUME`. `ENTRYPOINT` the binary's absolute
  path, `CMD` its default arguments.
- **Last instruction**: `RUN ["<binary>", "--version"]`, exec form.

Done when every answer from step 1 appears in the Containerfile or its
header, and `hadolint` passes.

### 3. Track its versions

Write `containers/<name>/docker-bake.hcl`, modeled on garage's: one
`target` with `name`, `context`, `dockerfile = "Containerfile"`, a
`matrix` of `debian` and `base` (`{ version, checksum }`, the checksum is
the tag's commit), `args` and `tags`. `depType=automerge` in the
`# renovate:` comment only when the server test covers what a release can
break. No `renovate.json5` change.

Done when the build check's `--print` shows the tag and arguments, and
`renovate.yml`'s `extract` job would pass (one dependency per
`# renovate:` comment; see its command).

### 4. Document it

Write `containers/<name>/AGENTS.md` and `REFERENCES.md`, shaped like the
reference image's, plus `CLAUDE.md`, a symlink to `AGENTS.md`:

- `AGENTS.md`: what the image is, where its runtime contract is, the
  rules a later change must keep, the smoke tests, and an *Updates*
  section: what a version bump needs and whether it automerges (the PRs
  point there)
- `REFERENCES.md`: upstream and where in its source to read (release
  build, flags, docs), then each decision with its reason

Done when every decision of step 2 has its reason in `REFERENCES.md`.

### 5. Verify

Run the build check's `--set '*.output=type=docker'` build: it runs the
server test. Then:

- `docker create` and `docker export | tar -tv`: the binary root's, state
  folders 65532's
- `docker run` as the runtime contract says, with a named volume,
  `--read-only --cap-drop all --security-opt no-new-privileges`: the
  health endpoint answers and the logs show no error

Done when the build is green and the hardened container serves.
