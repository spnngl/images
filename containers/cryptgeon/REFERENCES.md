# cryptgeon: references

## Sources

- Upstream: `github.com/cupcakearmy/cryptgeon` at tag `v<BASE_VERSION>`:
  `Dockerfile` (release build and image), `packages/backend/src/config.rs`
  and `store.rs` (environment variables, Redis), `main.rs` (routes),
  `docker-compose.yaml` (Redis run in memory)
- Docs: `README.md`, *Environment Variables*
- `github.com/containerd/containerd`, `internal/cri/server/container_stop.go`:
  the CRI sends the image's `StopSignal` when the pod sets none
- Upstream commit `9e69730` (after 2.9.3): unknown paths answer 200

## Decisions

- **Static musl binary on `scratch`**, where upstream's is Alpine with
  curl: nothing in the image but the server, its frontend and the
  license.
- **Redis without TLS** (`tls-native-tls` removed): it links OpenSSL,
  which a static musl build only gets by vendoring it, a second patch
  to upstream's `Cargo.toml` and a C library to keep current. Redis runs
  beside the server, in memory, so `rediss://` is unsupported:
  `Client::open` fails at startup. `cargo update --workspace` drops the
  TLS crates from `Cargo.lock`; the build checks no other crate moved,
  then builds `--locked`.
- **`rust:<version>-trixie`, musl target:** rustup's musl targets link
  statically by default; `musl-gcc` (`musl-tools`) builds the C code
  (ring, zstd). The version is `Cargo.toml`'s (`CARGO_PKG_VERSION`).
- **`cargo auditable`** embeds the crate list in the binary: without
  it, the SBOM and the scans see no Rust dependency.
- **`node:<version>-trixie-slim`, pnpm through corepack:** upstream's
  Node major (`.nvmrc`) and pnpm (`packageManager`), which corepack
  verifies. `--frozen-lockfile`: `pnpm-lock.yaml`'s versions and
  hashes. The frontend is static files, the same on every platform.
- **One `source` stage**, `ADD --checksum` once, read by both builds.
- **Built and tested as UID 65532:** install scripts, build scripts and
  the test server run without root, each build in its own copy of the
  source. A cache keeps the owner it was created with: hence ids of
  their own.
- **Server test in the build stage**, with Valkey from the snapshot (as
  upstream's compose file runs it): the server exits without Redis and
  has no `--version`, and `scratch` has no shell. Same reason for no
  final-stage `RUN`.
- **Upstream's paths and `REDIS` default** (`redis://redis/`, its
  compose service), so its docs and compose file apply.
  `FRONTEND_PATH` is absolute: it holds whatever the working directory.
  `WORKDIR /app`, upstream's: the server reads a `.env` there
  (`dotenv`).
- **Not root, unlike upstream:** the port is above 1024 and the server
  writes nothing, so it runs with a read-only root filesystem.
- **No CA bundle:** no outbound TLS.
- **`LICENSE` only:** upstream's `licenses.csv` counts licenses, it
  names no dependency.
- **No `HEALTHCHECK`:** no curl in the image, and Kubernetes ignores it.
- **`STOPSIGNAL SIGKILL`:** the server installs no SIGTERM handler, and
  the kernel drops a signal PID 1 doesn't handle, so a stop waited out
  its timeout (Docker 10 s, Kubernetes' grace period). It has no
  graceful shutdown to lose; Docker and containerd's CRI honour the
  image's signal. Not `tini`: a second binary for the same result.
- **Frontend packages in the SBOM** (`BUILDKIT_SBOM_SCAN_STAGE` on
  `frontend-files`): the bundle names no package, so scanners saw none.
  The stage holds `node_modules/.pnpm` and the built frontend only: the
  `frontend` stage would add node's image (Debian packages, npm,
  corepack). Build tools (vite, typescript) are listed too: pnpm's
  store doesn't tell them apart, some (svelte, `@sveltejs/kit`) are in
  the bundle.
- **404 on note links kept** (Known issue in `AGENTS.md`): fixed
  upstream, not released; no patch to carry.
