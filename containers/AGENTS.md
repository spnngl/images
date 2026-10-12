# Application images

An upstream app run as a container, not a host, one per
`containers/<name>/`. `.github/workflows/build-apps.yml` finds the
Containerfile and Dalec images and builds them with `docker buildx`: a
new one needs no workflow change. BuildKit's source:
`github.com/moby/buildkit` (`frontend/dockerfile/docs`).

## Pick the build

By what the app needs at runtime; name that need in the image's
`REFERENCES.md`.

- One static binary (Go with `CGO_ENABLED=0`, Rust on musl): a
  Containerfile on `scratch`, skill `add-containerfile-image`.
- Distro packages (an interpreter, shared libraries, tools it execs):
  Dalec, skill `add-dalec-image`.
- Docker's hardened Debian packages and the DHI catalog's build steps:
  a DHI definition, skill `add-dhi-image`. When to pick it over Dalec
  is not decided yet.

## Rules

- **Build context** is the image's own folder: it sees no other image's
  files. Its `.dockerignore` (copied from another image) keeps the
  Containerfile, `spec.yml`, docs and scripts out: BuildKit reads only
  `.dockerignore`, never `.containerignore`.
- **`BASE_VERSION`** is the upstream release and the image's tag,
  written once: CI reads it.
- **Shell-less**: the final image has no shell, so everything it runs is
  exec form, with absolute paths.
- **User** `65532:65532`, numeric so `runAsNonRoot` can check it. Root
  only when the app needs it, with the reason in the header
  (`cs-firewall-bouncer`, `nftables-exporter`).
- **Runtime contract** (ports, volumes, environment) lives in the
  Containerfile's or spec's header, or in the image's `AGENTS.md`.

## Limits

DHI images (`dhi.yaml`) are built locally only: `build-apps.yml` finds
`spec.yml` and `Containerfile` alone and has no `dhi.io` login, which
the `dhi.io/build` frontend needs. CI support will also pick the SBOM
generator (`dhi.io/scout-sbom-indexer`, as the DHI docs, or BuildKit's)
and give Renovate `dhi.io` credentials for the frontend's tags.

## Build check

```sh
docker buildx build -f containers/<name>/Containerfile containers/<name>/
docker buildx build -f containers/<name>/spec.yml --target trixie/container containers/<name>/
docker buildx build -f containers/<name>/dhi.yaml containers/<name>/   # after docker login dhi.io
```

The build runs the image's smoke test.
