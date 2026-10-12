# mc: references

## Sources

- Upstream: `github.com/pgsty/mc` at tag `<BASE_VERSION>`:
  `.github/workflows/release.yml` and `.github/goreleaser.yml` (release
  build), `cmd/` (flags and variables)
- Archived original: `github.com/minio/mc`; docs
  <https://silo.pgsty.com>

## Decisions

- **pgsty/mc, not minio/mc:** minio/mc is archived (last release
  `RELEASE.2025-08-13T08-35-41Z`), its dependencies frozen, and it still
  calls services MinIO Inc. runs (update feed, SUBNET, telemetry, the
  `play` alias). pgsty/mc forks its final commit and maintains it with
  Silo, in one release process: security fixes, dependency and Go
  updates, Silo fixes, those services cut off, `mc update` disabled.
  Silo's `go.mod` pins it; Pigsty supports minio/mc against Silo on a
  best-effort basis only. Upstream's archives call the binary `mcli`,
  its image `mc`.
- **`MC_CONFIG_DIR=/config`:** mc writes its config (`config.json`,
  `share/`, `certs/CAs/`) at every start, and its default, `~/.mc`,
  needs a `HOME` the image hasn't. No `VOLUME`: with aliases in
  `MC_HOST_<alias>`, the config is disposable; a volume keeps `mc alias
  set`'s aliases.
- **No S3 server in the test:** building one would double the build.
- **The image holds the binary, Debian's CA bundle** (TLS to S3
  servers), `LICENSE`, `NOTICE` and `CREDITS`.
