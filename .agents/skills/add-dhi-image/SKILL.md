---
name: add-dhi-image
description: Add or change an application image built from a Docker Hardened Images definition, containers/<name>/dhi.yaml, on Docker's hardened Debian 13 packages. Use when asked for a DHI image, or when editing a dhi.yaml.
---

# Add a DHI image

A DHI definition is declarative YAML that BuildKit builds with Docker's
`dhi.io/build` frontend (the `# syntax=` line): packages, build stages,
accounts, paths, entrypoint. The runtime packages come from Docker's
**hardened** Debian repository, rebuilt from source by Docker and signed.

The frontend is closed source. The **catalog** is the schema: clone
`github.com/docker-hardened-images/catalog` (`git_clone`), runtime
definitions in `image/<app>/debian-13/<version>.yaml` (the `-dev` and
`-compat` files are other variants). Use only fields some catalog
definition uses, in the shape it uses them. The docs are
`content/manuals/dhi/how-to/build.md` and `hardened-packages.md` in
`github.com/docker/docs`. This repository has no DHI image yet: the
catalog is the **reference image**.

Building needs `docker login dhi.io`, with a Docker ID; never commit its
credentials. CI support (`build-apps.yml` discovery, the `dhi.io` login,
the SBOM generator) is a separate task (ARCHITECTURE.md, "Known
limits"): this skill's changes stay in `containers/<name>/`,
`renovate.json5` and ARCHITECTURE.md.

The final image is **shell-less** (`containers/AGENTS.md`): its packages
are the app's runtime closure, without `bash`, `busybox` or `coreutils`.

## Unverified until the first build

No DHI image has been built here yet. These rules rest on reading the
catalog, not on a build; step 6 confirms or fixes each:

- `vars` aren't substituted: catalog definitions never reference them,
  so the release is written literally.
- `labels:` become the image config's labels.
- The frontend reads the build context, so `.dockerignore` matters.
- A pipeline step can start the server and reach it on `127.0.0.1`
  (catalog test steps set `privileged: true`).
- A package missing from the hardened repository resolves from Debian
  trixie, as catalog runtimes with only that repository install
  `libheif1` (`image/nextcloud/debian-13/`).

## Steps

### 1. Map upstream

Clone upstream at the release tag (`git_clone`) and answer each item from
its source, with the file that says so:

- how it ships: a source build (its release build: language, flags,
  ldflags, how it sets the version `--version` prints, the tag's commit
  from `git rev-parse <tag>^{commit}`), or a package in its own APT
  repository for trixie
- shared libraries, and every tool it execs, with the paths it tries
- every path it writes, and the flag or variable that moves it onto a
  volume
- listen ports (above 1024: it runs as non-root); whether it needs root
- outbound TLS (needs `ca-certificates`)
- license, as an SPDX id
- a health endpoint, and the smallest real operation through its API

Done when every item has an answer and a source file.

### 2. Find the catalog's way

Search the catalog for the app (`image/<app>/debian-13/`), for its
language's build step (`uses: go/build@v1`, `dpkg/build@v1`, …), and for
its runtime as a prebuilt artifact (`package/`, `artifacts:` with
`dhi.io/pkg-<runtime>`). Read the closest runtime definition whole: it
is the shape you copy.

Give each runtime dependency of step 1 a Debian package on `amd64` and
`arm64` (CI builds both). The hardened repository holds a subset of
Debian (no `python3`: the catalog ships runtimes as artifacts). A
version with a `dhi` suffix is Docker's hardened build; prefer it. List
the hardened candidates:

```sh
for arch in amd64 arm64; do curl -fsSL "https://dhi.io/deb/debian/main/dists/trixie/main/binary-${arch}/Packages.gz" | gzip -dc | awk -v RS= -v FS='\n' '$1 ~ /^Package: (<pkg>|<pkg>)$/' | grep -E '^(Package|Architecture|Version):'; done
```

Check the packages it lacks in Debian trixie, with the `apt-cache
policy` command of the `add-dalec-image` skill.

Done when you name the catalog definition you copy, and every runtime
dependency has a package on both platforms.

### 3. Write `containers/<name>/dhi.yaml`

- **`.dockerignore`**: copy another image's, plus a `dhi.yaml` line.
- **Frontend**: `# syntax=dhi.io/build:2-debian13`, first line. Debian 13
  only, like every application image.
- **Header comment**: what the image is, the build command, what a
  version bump needs beyond Renovate's PR, and the runtime contract:
  UID/GID, volumes, ports, required env or secrets.
- **Identity**: `name`, `image: ghcr.io/spnngl/images/<name>`,
  `variant: runtime`, `platforms` `linux/amd64` and `linux/arm64`.
- **Versions**: `vars.BASE_VERSION` is the upstream release and the
  image tag (`tags: [<release>]`), for CI to read once it builds DHI
  images. Write the release literally everywhere else it appears (the
  source URL, `spdx`, ldflags, the package pin). Renovate updates every
  copy (step 4).
- **Repository**: the hardened one, copied from a catalog definition:
  `deb [signed-by=/usr/share/keyrings/dhi-deb-main.gpg]
  http://dhi.io/deb/debian/main trixie main`, keyring
  `https://dhi.io/keyring/dhi-deb-gpg.D46852F6925E9F71.key`. The free
  Community tier: the Enterprise `security` repository needs
  credentials in the build.
- **Packages**: the runtime closure of step 2, unpinned, so they follow
  the hardened repository between rebuilds. `'!<pkg>'` drops a
  dependency the app never loads, as `image/static/debian-13/` does.
- **App from upstream's APT repository**: its `repositories` line and
  `keyring`, the package pinned `<pkg>=<epoch>:<version>`, and a
  `mappings` entry with its purl for the SBOM, as `build.md`'s Redis
  example. No build stage, unless its config needs one.
- **App built from source** (`contents.builds`), as the catalog
  definition of step 2:
  - source in `files`: `url: git+https://github.com/<owner>/<repo>.git#<tag>`
    and `checksum: <commit sha>`, so a moved tag fails the build, with
    an `spdx` block (name, version, purl, license)
  - build tools in the stage's own `contents.packages`, never in the
    image's
  - `pipeline` steps: the catalog's `uses:` step for the language,
    upstream's release flags, else `runs:` starting `set -eux -o
    pipefail`
  - a **server test** step after the build, as the Containerfile skill's:
    `--version` checked for the release, the server started on
    `127.0.0.1`, its health endpoint, one real operation, then killed.
    Its tools (`curl`) are build-stage packages.
  - `outputs`: only the files the image needs, `uid: 0`, `gid: 0`,
    `mode`: root's, the app can't rewrite them
- **Accounts**: the catalog's `nonroot` block, `run-as: nonroot`, UID and
  GID `65532`. Root only when the app needs it, with the reason in the
  header.
- **Paths**: each state folder a `type: directory` owned
  `65532`:`65532`: a new named volume takes their owner.
- **Metadata**: the catalog's Debian 13 `os-release` block, with
  `home-url` and `bug-report-url` `https://github.com/spnngl/images`.
  `labels` `org.opencontainers.image.{title,version,licenses,source}`,
  source `https://github.com/spnngl/images`, as the other images:
  ghcr.io links the package to the repository through it.
- **Runtime**: `entrypoint` the binary's absolute path, `cmd` its default
  arguments pointing config and data at the volumes, `work-dir`,
  `volumes`, `ports`. `environment` for settings that must survive a
  replaced `cmd`, `SSL_CERT_FILE` when it makes outbound TLS.

Done when every answer of steps 1 and 2 appears in the definition or its
header, and every source is pinned.

### 4. Track its versions

Renovate doesn't read definitions: add a `renovate.json5` custom manager
for the release under one dependency name, matching `vars.BASE_VERSION`
and every literal copy. A source build: modeled on sabnzbd's, the tag in
the source URL and its `checksum` in one match. An APT package: modeled
on jellyfin's, from upstream's repository. The first DHI image also adds
a manager for the `# syntax=` line of `containers/[^/]+/dhi\.yaml`, like
the Dalec frontend's. Add a `packageRules` entry: automerged only when
the server test covers what a release can break; otherwise
`prBodyNotes` saying what to check by hand.

Done when `renovate-config-validator --strict` passes and every pinned
version of the definition has a manager.

### 5. Document it

Add a `### containers/<name>` section to ARCHITECTURE.md, after the last
application image: its upstream and where in the source to read, the
catalog definition it copies, each decision with its reason, the server
test, the runtime contract, what a version bump needs. Add it to
"Updates", under automerged or reviewed by hand.

Done when every decision of step 3 has its reason in the section.

### 6. Verify

```sh
docker login dhi.io
docker buildx build -f containers/<name>/dhi.yaml -t <name>:test --load containers/<name>/
```

The build runs the server test. Then:

- `docker inspect`: the labels, user `65532`, entrypoint and volumes
- `docker create` and `docker export | tar -tv`: no shell, the binary
  root's, state folders 65532's
- `docker run` as the runtime contract says, with a named volume,
  `--read-only --cap-drop all --security-opt no-new-privileges`: the
  health endpoint answers and the logs show no error

Then settle each item of "Unverified until the first build": remove the
ones the build confirms, and fix the rules the build disproves.

Done when the build is green, the hardened container serves, and the
"Unverified" section is empty or gone.
