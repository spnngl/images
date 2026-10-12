---
name: add-containerfile-image
description: Add or change an application image built from images/<name>/Containerfile: one static binary (Go, Rust) on scratch. Use when an app ships as a static binary, or when editing an application image's Containerfile.
---

# Add a Containerfile image

`images/garage/` (Rust) and `images/minio/` (Go) are the **reference
images**: their comments carry the reason for each convention below. Read
the one in your language whole before writing, and copy its shape, with
its ARCHITECTURE.md section and "CI: `.github/workflows/build-apps.yml`".
`images/cs-firewall-bouncer/` is the exception, not a model: root with
`NET_ADMIN`, source not pinned to a commit.

The final image is `scratch`: the binary, and only the files the
Containerfile copies. It is **shell-less**: no shell, so the server test
runs in the build stage, and everything in the final stage is exec form.

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

### 2. Write `images/<name>/Containerfile`

- **Header comment**: what the image is, how it differs from upstream's,
  and the runtime contract: UID/GID, volumes, ports, required env or
  secrets, hardening it runs with (`--read-only`, no capability,
  `no-new-privileges`).
- **Version**: `ARG BASE_VERSION=<release>` before `FROM`, its tags URL
  in a comment.
- **Build stage**: the toolchain's official image on Debian trixie
  (`golang:<minor>-trixie`, `rust:<minor>-trixie`: the Debian release
  named, not the tag's default, which moves with Debian); its
  `ca-certificates` is the bundle the final image copies. Order: `ARG`, `ENV`, then
  `SHELL ["/bin/bash", "-xeuo", "pipefail", "-c"]` after the stage's last
  `ENV` or `ARG`: hadolint 2.15.1 checks the `RUN`s after either as
  `/bin/sh`.
- **Source**, as root: `ADD --link --checksum=<commit> <git url>#<tag>
  /src`, so a moved tag fails the build. `--keep-git-dir=true` only when
  the build reads git, with `git config --system --add safe.directory
  /src`: git refuses a repository another user owns.
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
- **State folders** created in the build stage, copied `--chown=65532:65532`:
  a new named volume takes their owner.
- **Final stage**: `FROM scratch`, `ARG BASE_VERSION`, labels
  `org.opencontainers.image.{version,licenses,source}` (source
  `https://github.com/spnngl/images`, `# hadolint ignore=DL3050` with its
  reason). `COPY --link`: the binary `--chown=0:0` (a `COPY` keeps the
  build user as owner; root's, the app can't rewrite it), the CA bundle
  when it makes outbound TLS, the license and notices in
  `/usr/share/doc/<name>/`.
- **Runtime**: `USER 65532:65532`, numeric so `runAsNonRoot` can check
  it. `ENV` for settings that must survive a replaced `CMD`. `EXPOSE`,
  `VOLUME`. `ENTRYPOINT` the binary's absolute path, `CMD` its default
  arguments.
- **Last instruction**: `RUN ["<binary>", "--version"]`, exec form.
- **Why-comments** on every non-obvious line (AGENTS.md).

Done when every answer from step 1 appears in the Containerfile or its
header, and `hadolint` passes.

### 3. Track its versions

Add a `renovate.json5` custom manager modeled on minio's: `ARG
BASE_VERSION` and the `--checksum` commit in one match (`currentDigest`),
so both change together. Add a `packageRules` entry: automerged only
when the server test covers what a release can break; otherwise
`prBodyNotes` saying what to check by hand.

Done when `renovate-config-validator --strict` passes and every pinned
version of the Containerfile has a manager.

### 4. Document it

Add a `### images/<name>` section to ARCHITECTURE.md, after the last
application image: its upstream and where in the source to read (release
build, flags, docs), each decision with its reason, the smoke tests, the
runtime contract, what a version bump needs. Add it to "Updates", under
automerged or reviewed by hand.

Done when every decision of step 2 has its reason in the section.

### 5. Verify

```sh
docker buildx build -f images/<name>/Containerfile -t <name>:test --load images/
```

The build runs the server test. Then:

- `docker create` and `docker export | tar -tv`: the binary root's, state
  folders 65532's
- `docker run` as the runtime contract says, with a named volume,
  `--read-only --cap-drop all --security-opt no-new-privileges`: the
  health endpoint answers and the logs show no error

Done when the build is green and the hardened container serves. Without
docker, report that the build was not run.
