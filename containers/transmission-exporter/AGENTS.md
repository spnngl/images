# transmission-exporter

Transmission exporter (Prometheus metrics of a Transmission daemon, Go)
built from source as tagged, no patch, one static binary on `scratch`.
Upstream publishes no image: this is the one its README names. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Code changes go upstream (`github.com/spnngl/transmission-exporter`)
  and reach the image as a tag.
- `--version` prints `main.version`, set by the build's
  `-X main.version=${BASE_VERSION}`; the server test checks it.
- Settings are variables (upstream's `Config`), so the image has an
  entrypoint and no `CMD`.
- The build stage compiles and tests as UID 65532, with
  `containers/minio`'s Go cache ids.
- Probes: liveness on `GET /` (always 200). `/metrics` answers 500 while
  Transmission is unreachable: a target for Prometheus, not a probe.

## Updates

Renovate follows upstream's tags. Minor and patch releases and golang
bumps are automerged on the server test (Debian's transmission-daemon
scraped through the exporter); a major release by hand: metric names
are public API, read
`https://github.com/spnngl/transmission-exporter/compare/v<old>...v<new>`
for renames that break dashboards and alerts. Check the variables and
`--version` against `cmd/transmission-exporter/main.go`. A
checksum-only update means upstream moved the tag. A Debian snapshot
bump can bring a transmission-daemon whose RPC the exporter misreads:
the test goes red, and the fix goes upstream.
