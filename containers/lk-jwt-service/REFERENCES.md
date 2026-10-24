# lk-jwt-service: references

## Sources

- Upstream: `github.com/element-hq/lk-jwt-service` at tag
  `v<BASE_VERSION>`: `.github/workflows/release.yaml` (release build),
  `Dockerfile` (image, `HEALTHCHECK`), `Cargo.toml` (binaries, features,
  license), `src/config.rs` (environment variables), `src/main.rs`
  (startup, no signal handler), `src/handler.rs` (`prepare_router`:
  routes; `verify_hs_token`; `process_get_token_cs_request`),
  `src/helper.rs` (`is_joined`: MSC4502 membership check;
  `LiveKitRoomServiceClient`: Twirp `CreateRoom`), `src/store.rs`
  (`new_redis_store`), `src/bin/healthcheck.rs`
- Docs: `README.md`, *Configuration*
- `github.com/containerd/containerd`: `internal/cri/server/`
  `container_create.go` copies the image's `StopSignal`,
  `container_stop.go` sends it when the pod sets none

## Decisions

- **Static musl binaries on `scratch`**, as upstream's image: one
  service with no runtime dependency. Upstream's release builds the
  same way (`CC=musl-gcc`, musl target); its image builds on Alpine.
- **`rust:<version>-trixie`, musl target:** rustup's musl targets link
  statically by default; `musl-gcc` (`musl-tools`) builds the crates'
  C code (ring, aws-lc-sys), with no cmake: aws-lc-sys builds with
  cc-rs, as in upstream's release. `--package lk-jwt-service`, as
  upstream's `Dockerfile` (`-p`): the root crate, not the workspace's
  `integration-tests`, `e2e-tests` or `xtask`.
- **`cargo auditable`** embeds the crate list in the binaries: without
  it, the SBOM and the scans see no Rust dependency.
- **Cargo's default features (none),** as upstream's image:
  `appservice-ping-trigger` adds an unauthenticated route that makes
  the service ping a caller-chosen homeserver.
- **Version tied by `ADD --checksum`:** neither binary prints a
  version, and `Cargo.toml`'s lags the release's.
- **Built and tested as UID 65532:** the crates' build scripts and the
  test server run without root and can't change the source (root's).
  `CARGO_HOME` and `RUSTUP_HOME` are set, so cargo needs no `HOME`. A
  cache keeps the owner it was created with: hence ids of their own.
- **Smoke test in the build stage:** the server needs its
  configuration to start, and `scratch` has no shell to run a test.
  As an application service, so the ping and C-S `get_token` routes
  exist and check `hs_token`.
- **Token issuance tested against a stub:** issuing a token is the
  service's job, and the check that only a room's members get one is
  what 0.x releases change. The C-S route takes the homeserver's word
  for the user (`X-Matrix-User-Identifier`), so it needs no OpenID over
  HTTPS, unlike the standalone endpoints; `LIVEKIT_CS_API_URL_OVERRIDES`
  points it at the stub over plain HTTP. A stub, not Synapse and
  LiveKit: two calls to answer, against two servers to install and
  configure. Python: an HTTP server and HMAC in its standard library;
  installed from the snapshot, as the rust image's comes with that
  image's base.
- **Valkey with a password** (Debian's `valkey-server`), as
  deployments run Redis: the server exits at startup when Redis refuses
  `LIVEKIT_REDIS_PASSWORD`, so its start covers AUTH and PING. Delayed
  leave, which writes the jobs, is untested.
- **Upstream's paths and `HEALTHCHECK`**, so its docs and the charts
  that run its image apply. The health check is a binary of upstream's,
  no shell needed; Kubernetes ignores it.
- **Entrypoint `/lk-jwt-service`**, where upstream only has `CMD`: the
  service takes no argument; Kubernetes' `command:` replaces it anyway.
- **UID 65532, where upstream's image runs as root (no `USER`):** the
  port is above 1024 and the server writes nothing, so it runs with a
  read-only root filesystem.
- **Debian's CA bundle**, for outbound TLS: homeservers' `.well-known`,
  OpenID userinfo and C-S API, LiveKit's API (rustls-native-certs
  reads it). Refreshed by the weekly rebuild.
- **Redis without TLS:** upstream builds the `redis` crate with no TLS
  feature, so `rediss://` fails at startup. `LIVEKIT_REDIS_PASSWORD` has
  no file variant, and the server logs the URL it builds with it
  (`store: connected to Redis addr=redis://:<password>@…`, at `info`).
  Plain TCP: Redis on a private network or behind a NetworkPolicy.
- **`LICENSE` only:** `Cargo.toml` says `AGPL-3.0-only`, the image's
  license; `LICENSE-COMMERCIAL` is Element's alternative, for a
  separate agreement.
- **`STOPSIGNAL SIGKILL`:** the server installs no SIGTERM handler, and
  the kernel drops a signal PID 1 doesn't handle, so a stop waited out
  its timeout (Docker 10 s, Kubernetes' grace period). It has no
  graceful shutdown to lose: delayed leave jobs are in memory, lost
  either way, or in Redis. Docker and containerd's CRI honour the
  image's signal. `tini` would be a second binary for the same result.
  Its cost: no grace period in which the pod keeps serving while it
  leaves its Service's endpoints; a `preStop` `sleep` handler gives it
  back (scratch has no `sleep` for an `exec` one).
- **Upstream releases reviewed by hand:** 0.x minor releases change
  who gets a token (0.9.0: room membership checks), beyond what the
  smoke test covers.
