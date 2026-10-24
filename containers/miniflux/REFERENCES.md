# miniflux: references

## Sources

- Upstream: `github.com/miniflux/v2` at tag `<BASE_VERSION>`: `Makefile`
  and `.github/workflows/build_binaries.yml` (release build),
  `packaging/docker/` (upstream's images), `internal/config/options.go`
  (variables and defaults), `internal/cli/` (flags, health check),
  `internal/http/server/` (probes, listeners, autocert),
  `internal/api/api.go` (API routes), `internal/version/version.go`
  (version, commit, build date)
- Docs: `https://miniflux.app/docs/`

## Decisions

- **Static binary on `scratch`:** upstream's release binaries are built
  with `CGO_ENABLED=0` (PostgreSQL through pure Go), and Miniflux execs
  nothing. Its state lives in PostgreSQL, Let's Encrypt certificates
  included (`internal/storage/certificate_cache.go`); it writes a file
  only for `LOG_FILE` (stderr by default) or a Unix socket in
  `LISTEN_ADDR` (`internal/http/server/server.go`). Hence a read-only
  root filesystem, and neither `VOLUME` nor `WORKDIR`.
- **The unprefixed tag:** each release has `<x.y.z>` and `v<x.y.z>` (Go's
  module tag) on one commit; upstream's release workflows trigger on the
  first. Renovate's `extractVersion` keeps the first alone, so it
  proposes each release once.
- **Upstream's release build:** `CGO_ENABLED=0 go build -ldflags "-s -w
  -X …version.Version=<BASE_VERSION>"`, as the Makefile's `linux-*`
  targets. The version is named, since the Makefile's `git describe
  --tags --exact-match` can pick either tag of the commit. Upstream's
  images use `make miniflux` (`-buildmode=pie`) instead: a Go PIE asks
  for a dynamic loader, which `scratch` lacks. The `golang` image's Go,
  newer than `go.mod`'s: the standard library's fixes.
- **`--keep-git-dir`:** go build stamps the commit and its date, which
  `-info` prints, as in upstream's builds from a checkout.
- **Built and tested as UID 65532,** as `containers/minio` (its
  REFERENCES.md), plus passwd and group entries for that user in the
  build stage: `initdb` and `postgres` look it up. `groupadd` first:
  `useradd -U` gives a UID above `UID_MAX` an unrelated GID.
- **Server test in the build stage, with Debian's PostgreSQL:** Renovate
  automerges `golang` bumps on it, and Miniflux starts only with a
  database. PostgreSQL comes from the Debian snapshot with its default
  cluster skipped (`createcluster.d`); the test makes its own,
  password-protected.
- **A feed fetched and parsed in the test:** fetching and parsing feeds
  is Miniflux's job, and a Go bump can break either. A stdlib file
  server built in the test serves it on 127.0.0.1 (the toolchain at
  hand, one tool fewer to pin), hence `FETCHER_ALLOW_PRIVATE_NETWORKS=1`
  for the test.
- **The login page loaded in the test:** the web UI renders through
  `html/template`, which a Go bump can break too; the API calls leave it
  untested.
- **`-healthcheck auto` tested with `LISTEN_ADDR=0.0.0.0:8080`:** the
  image's URL exactly, while the server listens on 127.0.0.1 alone:
  Linux connects 0.0.0.0 to the loopback.
- **Releases merged by hand:** with `RUN_MIGRATIONS=1` a release
  migrates the schema for good, and the test covers a new database only.
- **The image holds the binary, Debian's CA bundle** (feeds,
  integrations, Let's Encrypt), **Debian's time zones** (each user's
  time zone, `internal/timezone`; feed dates, `internal/reader/date`;
  `TZ`; trixie's `tzdata` has no legacy names such as `US/Eastern`:
  those are in `tzdata-legacy`), and `LICENSE` (Apache-2.0, no
  `NOTICE`). Both from the `golang` image, whose digest Renovate moves.
  Upstream's alpine image installs the same two.
- **`LISTEN_ADDR=0.0.0.0:8080`:** upstream's images'; the default,
  `127.0.0.1:8080`, is reachable from inside the container alone.
- **`HEALTHCHECK` with `miniflux -healthcheck auto`:** upstream's
  (`contrib/docker-compose/basic.yml`); the binary is its own probe, and
  `/healthcheck` checks PostgreSQL. It speaks plain HTTP to the first
  `LISTEN_ADDR` (`internal/cli/health_check.go`), hence TLS in a reverse
  proxy (the header).
- **`CERT_DOMAIN` documented as is:** its ACME challenge server binds
  port 80 (`setupAutocert`, `internal/http/server/server.go`), and UID
  65532 holds no capability: outside Docker, that takes
  `net.ipv4.ip_unprivileged_port_start=0`.
- **`RUN_MIGRATIONS` and `CREATE_ADMIN` left to the operator:** both act
  on the database, as in upstream's images.
