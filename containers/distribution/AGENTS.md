# distribution

Distribution (the OCI image registry, Go): upstream's release built from
source as tagged, no patch, one static binary on `scratch`, with a
config of its own (`config.yml`). Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- `config.yml` is both the image's default and the build test's: a
  change to it is tested by the build. Keys that must survive a replaced
  `CMD` go there or in the environment (`REGISTRY_<PATH>`).
- Deletes stay off by default: the server test expects the `405`.
- Keep `OTEL_TRACES_EXPORTER=none`.
- **Vulnerabilities**: no backport and no ignore entry (those files are
  for false positives, `.github/AGENTS.md`); the fix comes with the
  release that ships it, and the code scanning alerts are the list
  meanwhile.
- Probes: `GET /` on 5000 (`200`; `503`, as every request, once the
  storage health check fails), `GET /v2/` (`401` with auth). With
  `REGISTRY_HTTP_DEBUG_ADDR`: `/debug/health` and, with
  `REGISTRY_HTTP_DEBUG_PROMETHEUS_ENABLED=true`, `/metrics`.

## Smoke tests

The build stage's server test runs the image's `config.yml`: a blob and
an OCI manifest pushed through the API and pulled back byte for byte, a
manifest delete refused (`405`), a `SIGTERM` stop that exits `0`; then
`garbage-collect`, which must sweep an unreferenced blob alone, checked
at its path in the storage layout. The final stage runs
`registry --version`.

## Updates

Renovate follows the `v<x.y.z>` tags; minor and patch releases automerge
on the server test (`depType=automerge`), majors by hand. For a major, or
a failed build, check against upstream's tag:

- the build: `Dockerfile` (the `version` and `build` stages: ldflags,
  build tags) and `go.mod`'s Go version against the `golang` image's;
- the config: every key of `config.yml` in `configuration/configuration.go`,
  and upstream's `cmd/registry/config-*.yml` for new defaults;
- the storage: the release notes, for a change to the layout under
  `/var/lib/registry` (`registry/storage/paths.go`), with no way back.

A checksum-only update means upstream moved the tag.
