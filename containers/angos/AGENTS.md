# angos

Angos (OCI registry, Rust) built from source: one static musl binary
on `scratch`, its web UI embedded. Upstream's binary path (`/angos`) and
configuration, so its docs apply, but UID 65532 where upstream's runs as
65534: a bind mount, a key file or an `fsGroup` copied from its guides
takes 65532. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The build is upstream's release build, `cargo build --release` on
  the musl target, but linked by gcc, not its `rust-lld`
  (`REFERENCES.md`); Node's major from its `Dockerfile`. `build.rs`
  builds the UI with npm, so Node stays in the build stage.
- The build stage runs as UID 65532 (packages, the musl target and the
  npm link install as root): its cache ids end in `-65532`.
- The final stage copies from `angos-files`, the stage that puts the
  UI's packages in the SBOM: BuildKit scans no stage the target doesn't
  depend on.
- Probes: `GET /healthz` (liveness) and `/readyz` (readiness). The
  access policy governs them too: a deny-by-default policy needs a rule
  for their actions, as `smoke-test.toml` has.

## Smoke test

The build stage runs it (no `--version`: the version is read from the
crate list cargo auditable embeds, never grepped from the binary, where
amd64 inlines it): `smoke-test.toml` merged with a random user,
anonymous registry requests refused, the probes and the UI served, a
blob and a manifest pushed and pulled back, the pushes counted in the
metrics, a graceful stop.

## Updates

Renovate follows upstream's GitHub tags, never automerged: patch
releases carry breaking changes and storage migrations, some to run
before the new version starts. Before merging, read upstream's
`doc/how-to/upgrade.md` and `CHANGELOG.md` at the new tag, and check
the build against `.github/workflows/build.yaml` (release binary job)
and `Dockerfile`. Merging changes the image tag: deployments stay on
the old one until moved.
