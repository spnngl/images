# cryptgeon

Cryptgeon (encrypted, self-destructing notes and files) built from
source: the Rust server, one static musl binary, and its SvelteKit
frontend on `scratch`. Upstream's paths (`/app/cryptgeon`,
`/app/frontend`) and environment variables, so its docs apply; its
Redis client is built without TLS. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Static**: the server links nothing. The build removes Redis' TLS
  feature from `Cargo.toml` and fails when upstream's `redis = ...` line
  changes or `cargo update` moves a crate: rewrite the `sed` for the new
  line, keeping every other crate at upstream's version.
- Both builds are upstream's release build (its `Dockerfile`): `cargo
  build --release`, `pnpm run build`; Node's major is upstream's
  `.nvmrc`, pnpm upstream's `packageManager`.
- Both build stages run as UID 65532 (packages, the musl target and the
  pnpm shim install as root): their cache ids end in `-65532`.
- Probe: `GET /api/live`, 200 once Redis answers, 503 otherwise: a
  readiness probe. The server exits at startup when Redis is
  unreachable.
- `STOPSIGNAL SIGKILL` stays until upstream's server handles SIGTERM.
- The final stage copies the frontend from `frontend-files`, the stage
  that puts the frontend's packages in the SBOM: BuildKit scans no
  stage the target doesn't depend on.

## Known issue

At 2.9.3, every path but `/`, a note's link (`/note/<id>`) included,
answers the frontend's page with status 404: browsers show the note, a
proxy that replaces error pages breaks it. Upstream's fix (commit
`9e69730`) is in no release yet: remove this section on the release
that has it.

## Smoke test

The build stage runs it (the binary has no `--version`): Valkey in
memory, the server serving the built frontend, `/api/status` printing
`BASE_VERSION`, then one note created, previewed, burned and gone.

## Updates

Renovate follows upstream's GitHub tags, stable releases only. Minor and
patch releases, and Rust and Node minor bumps, are automerged (the smoke
test covers them); a major release is never. Before merging one, read
upstream's `CHANGELOG.md` at the new tag for changed environment
variables and API routes. A Node major follows upstream's `.nvmrc`.
