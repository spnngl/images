# Application images

An upstream app run as a container, not a host, one per
`containers/<name>/`. `.github/workflows/build-apps.yml` finds and builds
them with `docker buildx` (ARCHITECTURE.md, "CI:
`.github/workflows/build-apps.yml`"): a new image needs no workflow
change. DHI images are the exception: CI doesn't build them yet
(ARCHITECTURE.md, "Known limits").

## Pick the build

By what the app needs at runtime; name that need in the image's
ARCHITECTURE.md section.

- One static binary (Go with `CGO_ENABLED=0`, Rust on musl): a
  Containerfile on `scratch`, skill `add-containerfile-image`.
- Distro packages (an interpreter, shared libraries, tools it execs):
  Dalec, skill `add-dalec-image`.
- Docker's hardened Debian packages and the DHI catalog's build steps:
  a DHI definition, skill `add-dhi-image`. When to pick it over Dalec
  is not decided yet.

## Sources of truth

BuildKit: `github.com/moby/buildkit` (`frontend/dockerfile/docs`).

## Rules

- **Build context** is the image's own folder: it sees no other image's
  files. Its `.dockerignore` (copied from another image) keeps the
  Containerfile, `spec.yml` and scripts out; BuildKit ignores
  `.containerignore`.
- **`BASE_VERSION`** is the upstream release and the image's tag,
  written once: CI reads it.
- **Shell-less**: the final image has no shell, so everything it runs is
  exec form, with absolute paths.
- **User** `65532:65532`, numeric so `runAsNonRoot` can check it. Root
  only when the app needs it, with the reason in the header
  (`cs-firewall-bouncer`, `nftables-exporter`).
- **Secrets** come from the container's environment.

## Build check

```sh
docker buildx build -f containers/<name>/Containerfile containers/<name>/
docker buildx build -f containers/<name>/spec.yml --target trixie/container containers/<name>/
docker buildx build -f containers/<name>/dhi.yaml containers/<name>/   # after docker login dhi.io
```

The build runs the image's smoke test.
