# Application images

An upstream app run as a container, one per `containers/<name>/`.
`.github/workflows/build-apps.yml` reads the targets of every
`docker-bake.hcl` (`docker buildx bake --print`) and builds the
Containerfile and Dalec ones: a new image needs no workflow change.
BuildKit's source: `github.com/moby/buildkit`
(`frontend/dockerfile/docs`); Bake's: `github.com/docker/buildx`
(`bake/`).

## Versions: `docker-bake.hcl`

Every version is written once, in the image's `docker-bake.hcl`, never
in a Containerfile or spec. `containers/docker-bake.hcl` holds what all
images share: the Debian releases (`DEBIAN`), the Debian snapshot
(`DEBIAN_SNAPSHOT`) and the functions that make tags and build
arguments. Each image's `docker-bake.hcl` has one `target` whose
`matrix` lists what to build:

- `debian`: the Debian release, one per image (`["13"]`): tags don't
  name it, so a second would push the same tags;
- `base`: `{ version, checksum }`, the upstream release (`BASE_VERSION`,
  also the tag) and its commit (`BASE_CHECKSUM`, checked by `ADD
  --checksum`: a moved tag fails the build). Several entries build
  several release lines (haproxy);
- one entry per other pinned source (`PAR2_VERSION`, `UV_VERSION`).

Each version is preceded by a `# renovate: datasource=... depName=...`
comment (then `packageName`, `registryUrl`, `versioning`,
`extractVersion`, `depType`, in that order): the one Renovate manager
reads it, with the next line's quoted version and checksum. A version
without the comment is never updated; the `extract` job of
`.github/workflows/renovate.yml` fails on it. `depType=automerge` for
what is tested enough to merge alone (patch and minor),
`automerge-all` for majors too (`renovate.json5`).

Tags are `<version>`, plus `<major.minor>` for an image with several
lines, always written `tags("<name>", [<versions>])`: `tags()` names
every registry. The Containerfile or spec gets the versions as build
arguments **without a default** (a Dalec spec: an empty one): a build
without Bake fails on the first `RUN`, never on a stale version. What
differs between release lines goes in the Containerfile, as a `case` on
`BASE_VERSION`.

The Debian packages a Containerfile installs come from
`snapshot.debian.org` at `DEBIAN_SNAPSHOT_VERSION` (trixie's apt has no
`--snapshot`: the build stage rewrites
`/etc/apt/sources.list.d/debian.sources`), and the build stage checks the
base's release against `DEBIAN_CODENAME`. Dalec specs' packages follow
the archive (Dalec cannot pin them): the weekly rebuild and the SBOM
cover them. So do git's: its build stage is Alpine's (Debian has no
static libcurl), whose branch keeps only each package's newest build.

## Pick the build

By what the app needs at runtime; name that need in the image's
`REFERENCES.md`.

- One static binary (Go with `CGO_ENABLED=0`, Rust on musl): a
  Containerfile on `scratch`, skill `add-containerfile-image`.
- Distro packages (an interpreter, shared libraries, tools it execs):
  Dalec, skill `add-dalec-image`.
- A C binary linking a few Debian libraries: a Containerfile on
  distroless' `cc-debian13`, the packages it lacks copied with their
  dpkg status (`containers/haproxy`); none when distroless has them
  all (`containers/valkey`).
- A Node.js app: a Containerfile on distroless' `nodejs<major>-debian13`,
  built by the full Node image (`containers/seerr`).
- A Python app whose compiled modules come as PyPI wheels: a
  Containerfile on distroless' `python3-debian13`, the modules from a
  hash-pinned lock installed with uv, the Debian packages it execs copied
  with their dpkg status (`containers/bazarr`).
- Data other images copy (lists, databases): `containers/datalists`,
  on `scratch`, tagged `latest`.
- A distribution's root filesystem, for CI jobs that build its
  packages: `containers/gentoo`, Gentoo's stage3 on `scratch`, unpinned
  and tagged by flavor.
- Docker's hardened Debian packages and the DHI catalog's build steps:
  a DHI definition, skill `add-dhi-image`. When to pick it over Dalec
  is not decided yet.

## Rules

- **Build context** is the image's own folder: it sees no other image's
  files. Its `.dockerignore` (copied from another image) keeps the
  Containerfile, `spec.yml`, docs and scripts out: BuildKit reads only
  `.dockerignore`, never `.containerignore`.
- **`FROM` digests** stay in the Containerfile: Renovate's dockerfile
  manager updates them. A builder that differs per release line
  (kubectl's golang) comes from Bake instead: a `FROM` line can't vary.
- **Shell-less**: the final image has no shell, so everything it runs is
  exec form, with absolute paths. Busybox excepted: a shell is its
  purpose; git, built `FROM` busybox: hooks, aliases and some of its
  commands run through `/bin/sh`; and gentoo, a build environment.
- **User** `65532:65532`, numeric so `runAsNonRoot` can check it. Root
  only when the app needs it, with the reason in the header
  (`cs-firewall-bouncer`, `nftables-exporter`, `gentoo`).
- **File times**: CI clamps the layers' file times to
  `SOURCE_DATE_EPOCH`. An image whose file times matter sets
  `output = ["type=image,rewrite-timestamp=false"]` on its target;
  `build-apps.yml` reads that option alone (`containers/gentoo`).
- **Runtime contract** (ports, volumes, environment) lives in the
  Containerfile's or spec's header, or in the image's `AGENTS.md`.

## Limits

DHI images (`dhi.yaml`) are built locally only: `build-apps.yml` finds
`spec.yml` and `Containerfile` alone and has no `dhi.io` login, which
the `dhi.io/build` frontend needs. CI support also has to pick the SBOM
generator (`dhi.io/scout-sbom-indexer`, as the DHI docs, or BuildKit's)
and give Renovate `dhi.io` credentials for the frontend's tags.

## Build check

```sh
f=(-f containers/docker-bake.hcl -f containers/<name>/docker-bake.hcl)
docker buildx bake "${f[@]}" --print '<name>*'    # the targets, tags and arguments
docker buildx bake "${f[@]}" '<name>*' --set '*.output=type=docker'
docker buildx build -f containers/<name>/dhi.yaml containers/<name>/   # DHI: after docker login dhi.io
```

The build runs the image's smoke test. Bake's target is named after the
image, with the line and the Debian release when there are several
(`haproxy-3-2-debian13`); `--print` lists them.
