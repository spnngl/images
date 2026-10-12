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
- The build stage builds and tests as UID 65532, with Go caches of its
  own ids; the binary is copied owned by root.
- `--certs-dir /certs` is in the entrypoint; settings that must survive
  a replaced `CMD` go in the entrypoint or the environment.
- Keep `MINIO_UPDATE=off`.
- Probes: `GET /minio/health/live` and `/minio/health/ready` on 9000.

## Updates

Renovate follows the repository's tags, never automerged: a release can
rewrite the data for good; back up `/data` first.
