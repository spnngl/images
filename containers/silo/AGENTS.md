# silo

Silo (S3-compatible object storage, Go), the maintained community fork
of the MinIO server by Pigsty, built from source as tagged, no patch,
like `containers/minio`: same build, user, layout and rules; read
`containers/minio/AGENTS.md`. Only the differences are here. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Compatible with MinIO by contract: `MINIO_*` variables, `/minio/*`
  routes, `x-minio-*` headers, `minio_*` metrics, the `.minio.sys`
  on-disk format. The binary is `silo` (no `minio` alias).
- `HEALTHCHECK` is upstream's `silo healthcheck ready`. It reads
  `MINIO_ADDRESS` (a `--address` flag is invisible to it), and repeats
  `--certs-dir`, since a `HEALTHCHECK` doesn't go through the entrypoint.
- No `MINIO_UPDATE`: Silo removed in-place updates and warns when it is
  set.

## Updates

Renovate follows the repository's tags, automerged once CI passes, major
included: versioned by date, a new year is a major update. A release
can't be rolled back once it wrote to `/data`: back it up anyway. What
changed: `https://github.com/pgsty/silo/compare/<old>...<new>`.
