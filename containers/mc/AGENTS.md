# mc

pgsty/mc (MinIO Client, the `mc` S3 command-line client, Go) built from
source as tagged, no patch, one static binary on `scratch`, like
`containers/silo`: same build, user and layout. Same commands, config
and `mc` name as minio/mc, whose docs apply. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/bin/mc"]`, no `CMD`, upstream's: arguments are
  mc's (`docker run <image> ls <alias>/<bucket>`).
- `MC_CONFIG_DIR=/config`, owned by the image's user, no `VOLUME`.
- The build stage's test uses local files only (`--version`, `mc cp`
  and `mc cat` of a 1 MiB file, the config in `MC_CONFIG_DIR`); the S3
  code isn't exercised. The final stage runs `--version`.
- `mc find --exec` and `--autocompletion` run other programs: they fail.

## Updates

Renovate follows the repository's tags, automerged once CI passes, major
included (versioned by date): mc holds no data, the previous image
undoes a bad release. What changed:
`https://github.com/pgsty/mc/compare/<old>...<new>`.
