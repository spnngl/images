# distribution: references

## Sources

- Upstream: `github.com/distribution/distribution` at tag
  `v<BASE_VERSION>`: `Dockerfile` (release build and upstream's image),
  `cmd/registry/` (the binary and upstream's configs),
  `configuration/configuration.go` (keys and `REGISTRY_*` variables),
  `registry/registry.go` (`serve`, drain, debug server), `tracing/`
- Docs: `docs/content/about/` (`configuration.md`, `deploying.md`),
  published at `https://distribution.github.io/distribution/`

## Decisions

- **Static binary on `scratch`:** no cgo and the registry execs nothing;
  every storage driver is Go, compiled in.
- **Commit pinned** (`ADD --checksum`), no `.git`: the ldflags take the
  version and revision from `BASE_VERSION` and `BASE_CHECKSUM`.
- **Upstream's release build:** its `Dockerfile`, which makes the
  release binaries: `CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X
  …version.version=<BASE_VERSION> -X …version.revision=<commit> -X
  …version.mainpkg=…"`, no build tag, so `--version` prints the release
  without its `v`. Modules from `vendor/`. The `golang` image's Go, newer
  than `go.mod`'s: the standard library's fixes.
- **Built and tested as UID 65532:** the build and the server get no
  root; the source stays root's. A cache keeps the owner it was created
  with: hence an id of its own.
- **Server test in the build stage:** Renovate automerges `golang` bumps
  and the registry's minor and patch releases on it. It runs the shipped
  `config.yml`, so a config the release no longer accepts fails the
  build. It runs `garbage-collect` too: the one command that deletes
  data, and its storage paths (`registry/storage/paths.go`) are what a
  release must keep reading.
- **A config of its own, not upstream's `config-dev.yml`** (the one its
  image ships): that one logs at debug, enables deletes and starts the
  debug server, which also serves `net/http/pprof`. `config-example.yml`
  enables htpasswd at `/etc/registry`, a file the registry writes when
  missing, refused by a read-only root.
- **Deletes off:** upstream's default; a deleted manifest is gone for
  every client. `REGISTRY_STORAGE_DELETE_ENABLED=true` turns them on, for
  garbage collection.
- **No debug server:** it serves pprof beside `/metrics` and
  `/debug/health`, on its own port. `REGISTRY_HTTP_DEBUG_ADDR` turns it
  on, for a private network.
- **`draintimeout: 5s`:** without it, the registry has no `SIGTERM`
  handler and dies by the signal, cutting uploads. 5s ends under Docker's
  10s stop timeout.
- **No authentication by default:** htpasswd needs a file, token auth a
  token server; both are the operator's. Upstream's default too.
- **`OTEL_TRACES_EXPORTER=none`:** upstream's image's. Without it,
  OpenTelemetry's `autoexport` sends every span to `localhost:4318` and
  logs each failure.
- **The image holds the binary, `config.yml`, Debian's CA bundle** (S3,
  GCS and Azure storage, proxy upstream, notification endpoints),
  `LICENSE` (Apache-2.0) and the license, notice and patent files of
  `vendor/`, under their module paths: the binary compiles those modules
  in, and their licenses (Apache-2.0's NOTICE, BSD, MIT) ask for the
  text with a binary.
- **Vulnerabilities of the vendored modules, unpatched:** the fix comes
  with upstream's release. A backport is a `go.mod` change upstream's
  tests never ran. The pull request scan fails only on a fixable
  Critical the pushed image doesn't already have.
- **`/var/lib/registry` copied with its owners:** the user's, so a new
  volume takes them; `/var` and `/var/lib` root's, which a `COPY
  --chown` would give to the user.
- **Upstream's paths and `CMD`** (`/etc/distribution/config.yml`,
  `/var/lib/registry`, `serve <config>`): its docs and deployments apply
  unchanged.
- **No `HEALTHCHECK`, no `WORKDIR`:** the binary has no probe command
  and the image no shell; every path is absolute.
