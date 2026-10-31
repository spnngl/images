# trivy

Trivy (vulnerability, misconfiguration and secret scanner, Go): built
from source as tagged, no patch, one static binary on `scratch`, run as
a CLI or as `server`. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- Build as upstream's release does (`goreleaser.yml`, `build-linux`): set
  only the `app.ver` ldflag, to the tag without its `v`.
- The binary is `/usr/bin/trivy`: `containers/angos` puts it on its
  `PATH`.
- State lives under `/var/cache/trivy` alone (`TRIVY_CACHE_DIR`, and
  `XDG_DATA_HOME` for plugins, modules and VEX repositories). `/tmp`
  stays in the image, mode 1777.
- Keep `TRIVY_DISABLE_TELEMETRY` and `TRIVY_SKIP_VERSION_CHECK` true.
- No `git` and no shell in the image: its sources, the `git::` ones,
  are listed unavailable in the header.
- Probe: `GET /healthz` on 4954.

## Tests

The build stage's smoke test (its comment lists what it checks), and
`trivy --version` in the final stage, on each platform.

## Updates

Renovate follows Trivy's stable tags and automerges minor and patch
releases on the smoke test; major releases wait: read `CHANGELOG.md`'s
breaking changes. The test makes its empty database at the schema
version of `go.mod`'s trivy-db, so a release that needs another way to
open it fails the build. Check the build against `goreleaser.yml`, and
the variables against `pkg/flag/`. A checksum-only update means upstream
moved the tag.
