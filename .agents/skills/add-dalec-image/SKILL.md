---
name: add-dalec-image
description: Dalec application image, for apps needing distro packages at runtime (interpreter, shared libraries, exec'd tools). Use when adding one, or editing a containers/*/spec.yml.
---

# Add a Dalec image

Shared rules, versions and the build check: `containers/AGENTS.md`.

`containers/sabnzbd/` is the **reference image**: its `spec.yml` comments
carry the reason for each convention below. Read it whole, and copy its
shape, with its `AGENTS.md` and `REFERENCES.md`.

Dalec builds one Debian package, then installs it into an image built from
scratch out of that package's dependency **closure**: only what the spec
names exists at runtime. The image is shell-less and has no apt: wrapper
scripts, `sh -c` and `$VAR` in the entrypoint fail.

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

- **Frontend**: `# syntax=` with the same frontend tag as the other specs.
  Read Dalec at that tag (`git_clone` `github.com/project-dalec/dalec`):
  `website/content/` for docs, `docs/spec.schema.json` and the Go `yaml:`
  tags for field names. The docs drift from the schema (they say
  `workdir`; the field is `working_dir`): the schema wins.
- **Target**: `<Debian stable>/container`, today `trixie/container`, the
  one the Bake file's `target` names. Dependencies are trixie package names.
- **Header comment**: what the image is, the build command, what a
  version bump needs beyond Renovate's PR (a lock to regenerate, a patch
  to check), and the runtime contract: UID/GID, volumes, port, required
  env or secrets.
- **Versions** in `args`, **empty**: `BASE_VERSION` and `BASE_CHECKSUM`,
  then one pair per other pinned source; Bake passes the values (step 5).
  Dalec fails on an argument the spec doesn't declare: declare only what
  Bake passes (no `DEBIAN_*`).
- **Pinned** sources, so a version that doesn't match its checksum fails
  the build: git with `commit: ${BASE_VERSION}` (the tag) and `checksum:
  ${BASE_CHECKSUM}` (the commit sha), http with `digest`.
- **Repo files** (patches, locks): a `context: {}` source with
  `includes:`. Patches go under `patches.<source>`, each with a comment
  saying why.
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
  to a volume. `working_dir`, `volumes`, labels
  `org.opencontainers.image.{title,version,licenses,source}`. Dalec has no
  `EXPOSE`: state the port in a comment.

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
`containers/sabnzbd/sabnzbd-lock.sh`: versions read from the spec, only
`docker` and `curl` required. The spec installs it with `--require-hashes`
in a sandbox network step, the build's only network access.

Done when the script passes `shellcheck` and its lock sits beside the spec.

### 4. Write the tests

The spec's `tests` are the image's smoke test, run on every build. Tests
are shell-less too: each step's command is split into words like a shell
would, then run directly. Call each binary by absolute path, the path the
app itself finds first.

- one step per tool the app execs (step 1)
- the app's start command, asserting `${BASE_VERSION}` in its output

Done when every exec'd tool and the app itself have a step.

### 5. Track its versions

Write `containers/<name>/docker-bake.hcl`, modeled on sabnzbd's: one
`target` with `name`, `context`, `dockerfile = "spec.yml"`,
`target = "${DEBIAN[debian].codename}/container"`, a `matrix` (`debian`,
`base` as `{ version, checksum }`, one entry per other pinned source),
`args` (no `containerfile_args`) and `tags`. `depType=automerge` in a
`# renovate:` comment says it may merge alone. No `renovate.json5` change.

Done when the build check's `--print` shows the tag and arguments, and
every version has its `# renovate:` comment.

### 6. Document it

Write `containers/<name>/AGENTS.md` and `REFERENCES.md`, shaped like
sabnzbd's, plus `CLAUDE.md`, a symlink to `AGENTS.md`:

- `AGENTS.md`: what the image is, where its runtime contract is, the
  rules a later change must keep, the tests, and an *Updates* section:
  what a version bump needs and whether it automerges (the PRs point
  there)
- `REFERENCES.md`: upstream and where in its source to read, then each
  closure choice and patch with its reason

Done when every choice of steps 1 to 4 has its reason in
`REFERENCES.md`.

### 7. Verify

Run the build check's `--set '*.output=type=docker'` build: it runs the
tests. Then `docker run` the image as its runtime contract says (port
published, volumes writable by 65532), and check the app starts and
serves.

Done when the build is green and the container serves with its volumes
mounted.
