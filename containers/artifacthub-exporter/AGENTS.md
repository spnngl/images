# artifacthub-exporter

Artifact Hub exporter (Prometheus metrics of Artifact Hub packages and
repositories, Go) built from source as tagged, no patch, one static
binary on `scratch`. Upstream publishes a deb and an rpm, no image: this
is the one its README names. Runtime contract: the Containerfile's
header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- Code changes go upstream (`github.com/spnngl/artifacthub-exporter`)
  and reach the image as a tag.
- `--version` prints `main.version`, set by the build's
  `-X main.version=${BASE_VERSION}`; the server test checks it.
- Settings are variables (upstream's `Config`), so the image has an
  entrypoint and no `CMD`.
- The build stage compiles and tests as UID 65532, with
  `containers/minio`'s Go cache ids.
- The server test calls the real Artifact Hub: keep it to a handful of
  requests (one small package and the hub's totals), as the hub rate
  limits, and check metrics, not their live values.
- Probes: liveness on `GET /` (always 200). `/metrics` serves the last
  collection and never calls Artifact Hub: alert on
  `artifacthub_collection_last_success_timestamp_seconds`, not on a
  probe.

## Updates

Renovate follows upstream's tags. Minor and patch releases and golang
bumps are automerged on the server test (one package and the hub's
totals collected from artifacthub.io); a major release by hand:
metric names are public API, read
`https://github.com/spnngl/artifacthub-exporter/compare/v<old>...v<new>`
for renames that break dashboards and alerts. Check the variables and
`--version` against `cmd/artifacthub-exporter/main.go` and `config.go`.
A checksum-only update means upstream moved the tag. A red test with
no change of ours: Artifact Hub down, rate limiting, or its API
changed; rerun, then read the exporter's log in the build output.
