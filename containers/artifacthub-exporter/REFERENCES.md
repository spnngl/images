# artifacthub-exporter: references

## Sources

- Upstream: `github.com/spnngl/artifacthub-exporter` at tag
  `v<BASE_VERSION>`: `.goreleaser.yaml` (release build),
  `cmd/artifacthub-exporter/main.go` (`--version`, `.env`, shutdown),
  `cmd/artifacthub-exporter/config.go` (variables, defaults),
  `cmd/artifacthub-exporter/poller.go` (collection order, failures),
  `client.go` (API paths, pagination, retries), `README.md` (variables,
  metrics, rate limit)
- Artifact Hub's API: `https://artifacthub.io/docs/api/`

## Decisions

- **One static binary on `scratch`:** `CGO_ENABLED=0`
  (`.goreleaser.yaml`), and the exporter execs nothing.
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build.
- **Upstream's release build, version included:** `.goreleaser.yaml`'s
  flags, `-trimpath` and `-s -w -X main.version=<version>`, the version
  without its `v` as goreleaser's `{{ .Version }}`. No `.git`: the
  version needs none.
- **The `golang` image's Go**, newer than or equal to `go.mod`'s: the
  standard library's fixes. `GOTOOLCHAIN=local` (the image's): a
  `go.mod` asking for a newer Go fails the build instead of downloading
  a toolchain; the next `golang` bump fixes it.
- **Built and tested as UID 65532:** the exporter doesn't get root in
  the build, and the test runs it as the image does.
- **Server test against the real artifacthub.io, five requests:** the
  live API, its TLS through the CA bundle the image ships, and its
  answers decoded are what a release or a `golang` bump can break, and
  what upstream's unit tests fake with `testdata/`. Tiny, as the hub
  rate limits (429s past about 100 requests a minute, `README.md`) and
  CI builds each platform: one package, `helm/artifact-hub/artifact-hub`
  (Artifact Hub's own chart, in a repository of fewer packages than a
  search page: one page per search), takes the four package calls
  (repository search, package search, details, views), the hub's totals
  the fifth. A failed call holds back the target's
  `artifacthub_collection_last_success_timestamp_seconds`, checked for
  both; the values are live, so the checks want each metric, not a
  number. The wait covers the exporter's retries of a 429 (30 s, then
  60 s, `client.go`). The build depends on artifacthub.io being up:
  accepted, a red build is retried. The stop is checked too: on
  SIGTERM the exporter finishes its scrapes and exits 0. No API key:
  the public API answers without one, and the image holds no
  credential.
- **The image holds the binary, Debian's CA bundle** (Artifact Hub is
  https; Go reads `/etc/ssl/certs/ca-certificates.crt`) **and
  `LICENSE`** (Apache-2.0, section 4: its text goes with the binary;
  upstream has no `NOTICE`).
- **Port 8080:** upstream's `WEB_ADDR` default (`config.go`) and its
  README's `docker run -p 8080:8080`.
- **Credentials in variables:** upstream reads
  `ARTIFACTHUB_API_KEY_SECRET` only, no file variant; on Kubernetes,
  from a Secret through `env`. Optional: the public API answers without
  a key.
- **No `CMD`, no volume, no `WORKDIR`:** settings are variables, the
  exporter writes nothing. It reads an optional `.env` from its working
  directory, `/`, where the image has none.
- **No `HEALTHCHECK`:** nothing in the image can run a check.
