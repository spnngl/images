# lk-jwt-service

MatrixRTC Authorization Service (Rust): issues LiveKit tokens to Matrix
users and delegates their delayed leave events. Two static musl
binaries, the service and its health check, on `scratch`, at the paths
of upstream's `ghcr.io/element-hq/lk-jwt-service` and with its
`HEALTHCHECK`, so upstream's docs and charts apply. Runtime contract:
the Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Static**: a `NEEDED` entry in either binary fails the build.
- **Build** as upstream's release (`.github/workflows/release.yaml`):
  `--package lk-jwt-service`, Cargo's default features (none).
- The build stage compiles and tests as UID 65532 (only packages and the
  musl target install as root): its cache ids end in `-65532`.
- Probe: `GET /healthz`, 200 while the server runs; it checks nothing
  behind it (LiveKit, Redis, homeservers).
- `STOPSIGNAL SIGKILL` stays until upstream's server handles SIGTERM.

## Smoke test

The build stage runs it against Valkey and a stub (`/test/stub.py`, in
the Containerfile) standing in for the homeserver and LiveKit; the
Containerfile's comments list what it checks. Uncovered: the standalone
endpoints (OpenID over HTTPS), federation (S-S `get_token`), delayed
leave. The stub answers two calls of upstream's (`src/helper.rs`:
MSC4502 `is_joined`, Twirp `CreateRoom`): when the test goes red on an
update, compare them with the stub first.

## Updates

Renovate automerges Rust minor and patch bumps, the Debian snapshot and
the base digests, gated by the smoke test. Upstream releases are
reviewed by hand:

1. Read the release notes
   (`https://github.com/element-hq/lk-jwt-service/releases/tag/v<new>`).
2. Diff `README.md` (*Configuration*, security notes) and
   `src/config.rs` between the tags. Every new or renamed variable a
   deployment must set is in the Containerfile's header: a missing one
   fails the deployment at startup.
3. With a deployment's configuration, start a call from Element Call:
   done when it connects.

A checksum-only update means upstream moved the tag: find out why
before merging.
