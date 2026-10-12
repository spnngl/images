# minio

MinIO server (S3-compatible object storage, Go): upstream's last
release, built from source as tagged, no patch, one static binary on
`scratch`. Upstream is archived and source-only, with known
vulnerabilities it will never fix: only for networks where every client
is trusted. `containers/silo` is the maintained MinIO, the choice for
anything new. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- No backports and no ignore file for its vulnerabilities: the code
  scanning alerts are the current list.
- The build stage runs as UID 65532, with Go cache ids of their own
  (`containers/silo` and `containers/mc` reuse them).
- `--certs-dir /certs` is in the entrypoint; settings that must survive
  a replaced `CMD` go in the entrypoint or the environment.
- Keep `MINIO_UPDATE=off`.
- Probes: `GET /minio/health/live` and `/minio/health/ready` on 9000.

## Updates

Renovate follows the repository's tags, never automerged: a release can
rewrite the data for good. Before merging, read what changed
(`https://github.com/minio/minio/compare/<old>...<new>`) and back up
`/data`: the old version may not read what the new one writes. Check the
image's flags and variables (`--certs-dir`, `MINIO_CONSOLE_ADDRESS`,
`MINIO_UPDATE`) against `cmd/main.go` and `cmd/server-main.go`, and the
build against the `build` target of the `Makefile`. A checksum-only
update means upstream moved the tag.
