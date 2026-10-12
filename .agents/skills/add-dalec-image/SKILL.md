---
name: add-dalec-image
description: Dalec application image, for apps needing distro packages at runtime (interpreter, shared libraries, tools it execs). Use when adding one, or editing a containers/*/spec.yml.
---

# Add a Dalec image

`containers/sabnzbd/` is the **reference image**: its `spec.yml` comments carry
the reason for each convention below. Read it whole before writing, and
copy its shape. ARCHITECTURE.md, "`containers/sabnzbd`" and "CI:
`.github/workflows/build-apps.yml`", has the design.

Dalec builds one Debian package, then installs it into an image built from
scratch out of that package's dependency **closure**: only what the spec
names exists at runtime. The image is **shell-less**
(`containers/AGENTS.md`), and has no apt: wrapper scripts, `sh -c` and
`$VAR` in the entrypoint fail.

## Steps

### 1. Map the closure

Clone upstream at the release tag (`git_clone`) and list everything the app
touches at runtime:

- interpreter and its version (compiled modules must match trixie's, e.g.
  Python 3.13 / `cp313` wheels)
- shared libraries, and every tool it execs, with the names and paths it
  tries, in order
- language modules, and the versions upstream requires
- every path it writes (config, state, data, caches), and how to move each
  onto a volume: CLI flag, env variable, or a patch to upstream's defaults.
  Its install folder is read-only to the image's user.
- listen port; whether it needs root
- a command that proves it starts (`--version` after imports, `-T`, …)

Give each item a home: a trixie package, a source built in the spec, or a
hash-pinned lock (step 3). CI builds `amd64` and `arm64`: each home must
exist on both. Check packages on each platform; a package missing from the
output doesn't exist there:

```sh
docker run --rm --platform linux/<arch> debian:trixie sh -c 'sed -i "s/^Components: main$/Components: main non-free/" /etc/apt/sources.list.d/debian.sources && apt-get update -qq && apt-cache policy <pkg>...'
```

Done when every item has a home on both platforms.

### 2. Write `containers/<name>/spec.yml`

- **`.dockerignore`**: copy another image's.
- **Frontend**: `# syntax=` with the same frontend tag as the other specs.
  Read Dalec at that tag (`git_clone` `github.com/project-dalec/dalec`):
  `website/content/` for docs, `docs/spec.schema.json` and the Go `yaml:`
  tags for field names. The docs drift from the schema (they say
  `workdir`; the field is `working_dir`): the schema wins.
- **Target**: `<Debian stable>/container`, today `trixie/container`, the
  one `build-apps.yml` builds. Dependencies are trixie package names.
- **Header comment**: what the image is, the build command, what a
  version bump needs beyond Renovate's PR (a lock to regenerate, a patch
  to check), and the runtime contract: UID/GID, volumes, port, required
  env or secrets.
- **Versions** in `args`: `BASE_VERSION` is the upstream release, also the
  image tag. Every other pinned version is an arg too, each with its
  releases URL in a comment.
- **Pinned** sources, so a `BASE_VERSION` that doesn't match the spec fails
  the build: git with `commit: <tag>` and `checksum: <commit sha>`, http
  with `digest`.
- **Repo files** (patches, locks): a `context: {}` source with
  `includes:`. Patches go under `patches.<source>`, each with a comment saying why.
- **Build tools** trixie lacks: an `image:` source with `path:` to the
  binary, as the reference image does for `uv`.
- **Metadata**: `packager` and `vendor` `spnngl/images`, `revision: 1`,
  upstream's SPDX `license`.
- **Build**: `DEB_BUILD_OPTIONS: noautodbgsym` (the image would install the
  `-dbgsym` package). Each step runs in its own subshell (`sh`, `set -ex`)
  from the folder holding one folder per source: a `cd` ends with its step.
  `network_mode: sandbox` only for a hash-pinned lock.
- **Image**: absolute paths in `entrypoint`; `cmd` points config and data
  at the volumes. `user: "65532:65532"`; with no passwd entry, set `HOME`
  to a volume. `working_dir`,
  `volumes`, labels `org.opencontainers.image.{title,version,licenses,source}`.
  Dalec has no `EXPOSE`: state the port in a comment.

Closure pitfalls, each hit by the reference image:

- The base must have a dpkg database: distroless images fail
  (base-files' postinst).
- Debian ships some commands as shell scripts (`/usr/bin/7za`): point
  `image.post.symlinks` at the real binary, in `/usr/local/bin`, which
  comes before `/usr/bin` on the image's `PATH`.
- The minimal image is pruned: `/usr/share/locale` and apt state always,
  `/usr/share/{doc,man,info}` unless the spec declares a `docs`,
  `manpages` or `licenses` artifact. App data goes under `/usr/lib/<name>`.
- `extra_repos` apt config takes the one-line `deb [signed-by=…]` format
  only (Dalec names the file `*.list`). Use `envs: [install]` when only the
  image needs the repository.
- Python: compile bytecode at build time with `--invalidation-mode
  unchecked-hash`. The user can't write `/usr/lib`, and dpkg clamps file
  times, so mtime-based `.pyc` look stale.

Done when every closure item from step 1 appears in the spec and every
source is pinned.

### 3. Lock language modules

Only when Debian lacks the modules or has older ones than upstream
requires. Write a hash-pinned lock in `containers/<name>/`, generated by
`containers/<name>/<name>-lock.sh`, modeled on
`containers/sabnzbd/sabnzbd-lock.sh`: versions read from the spec, only `docker` and `curl` required. The spec installs it
with `--require-hashes` in a sandbox network step, the build's only
network access.

Done when the script passes `shellcheck` and its lock sits beside the spec.

### 4. Write the tests

The spec's `tests` are the image's smoke test, run on every build. Tests are
shell-less too: each step's command is split into words like a shell would,
then run directly. Call each binary by absolute path, the path the app
itself finds first.

- one step per tool the app execs (step 1)
- the app's start command, asserting `${BASE_VERSION}` in its output

Done when every exec'd tool and the app itself have a step.

### 5. Track its versions

Renovate doesn't read specs: add a `renovate.json5` custom manager
for each pinned version, modeled on sabnzbd's (a git source's version and
`checksum` in one match, so both change together), and a `packageRules`
entry saying whether it automerges, with `prBodyNotes` for what its PR
needs by hand.

Done when `renovate-config-validator --strict` passes and every pinned version of the spec has a manager.

### 6. Document it

Add a `### containers/<name>` section to ARCHITECTURE.md, after the last
application image: its upstream and where in the source to read, each
closure choice and patch with its reason, the tests, the runtime
contract, what a version bump needs. Add it to "Updates", under
automerged or reviewed by hand.

Done when every choice of steps 1 to 4 has its reason in the section.

### 7. Verify

```sh
docker buildx build -f containers/<name>/spec.yml --target trixie/container -t <name>:test containers/<name>/
```

The build runs the tests. Then `docker run` the image as its runtime
contract says (port published, volumes writable by 65532), and check the
app starts and serves.

Done when the build is green and the container serves with its volumes
mounted.
