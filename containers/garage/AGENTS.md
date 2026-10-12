# garage

Garage (S3-compatible distributed object store, Rust) built from source,
one static musl binary on `scratch`. Close to upstream's
`dxflrs/garage`: same paths (`/garage`, `/etc/garage.toml`,
`/var/lib/garage/{meta,data}`) and Cargo features, so upstream's docs
and Helm chart apply. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/garage"]`, `CMD ["server"]`: arguments are Garage's
  (`docker run <image> server --single-node`). A `command:` copied from
  upstream's docs drops its leading `/garage`.
- Cargo features follow upstream's release set, `nix/compile.nix`.
- The build stage compiles and tests as UID 65532; only packages and
  the musl target install as root. Its caches have ids ending in
  `-65532`.
- The build stage's server test uses `smoke-test.toml` (not in the
  image); the final stage only runs `--version`.
- Probe: `GET /health` on the admin API (`[admin]` in the config), no
  token: a readiness probe only, as it answers 503 during a cluster-wide
  outage.

## Updates

Renovate follows upstream's Forgejo tags. Minor and patch releases and
Rust bumps are automerged (the server test covers them); a major release
migrates the metadata and is never automerged. Before merging, read
upstream's migration guide
(`https://garagehq.deuxfleurs.fr/documentation/working-documents/migration-<major>/`)
and the release notes
(`https://git.deuxfleurs.fr/Deuxfleurs/garage/releases/tag/v<new>`).
Merging changes the image tag: nodes stay on the old one until moved,
following that guide.
