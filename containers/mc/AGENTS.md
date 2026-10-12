# mc

pgsty/mc (MinIO Client, the `mc` S3 command-line client, Go) built from
source as tagged, no patch, one static binary on `scratch`, like
`containers/silo`: same build, user and layout. Same commands, config
and `mc` name as minio/mc, whose docs apply. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Updates

Renovate follows the repository's tags, automerged once CI passes, major
included (versioned by date): mc holds no data, the previous image
undoes a bad release. What changed:
`https://github.com/pgsty/mc/compare/<old>...<new>`.
