# silo: references

## Sources

- Upstream: `github.com/pgsty/silo` at tag `<BASE_VERSION>`:
  `.github/workflows/release.yml` and `.github/goreleaser.yml` (release
  build), `cmd/` (flags and variables), `Dockerfile.distroless`
  (upstream's image)
- Console: `github.com/pgsty/silo-console`
- Docs: <https://silo.pgsty.com>

## Decisions

- **Why a fork:** MinIO Inc. wound down MinIO's community edition
  (console cut to a stub, no binaries or images, then the repository
  archived; see `containers/minio`). Silo forks the server under the
  same license (AGPL-3.0-or-later, no CLA) and maintains it: security
  fixes with a public advisory each, dependency and Go updates, a
  release every one or two months, the full console back, MinIO's
  telemetry and update checks removed. Not affiliated with MinIO Inc.
- **Next to `containers/minio`, not instead:** minio is MinIO's last
  release as upstream tagged it, without a third party's commits
  (hundreds on top); Silo is the maintained one. Moving from MinIO is a
  change of image on the same `/data`; back it up, moving back isn't
  promised.
- **Upstream's `HEALTHCHECK`:** built into the binary, so it runs on
  `scratch`, over HTTPS when `/certs` holds a key pair. Kubernetes
  ignores it: probes as `containers/minio`.
- **Automerged, major included:** the build stage tests the server, and
  Silo keeps the data format by contract.
