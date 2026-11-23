# speculaire: references

## Sources

- Upstream: `github.com/spnngl/speculaire` at commit `<BASE_CHECKSUM>`:
  `build/Containerfile` (build stage: image, packages,
  `CARGO_AUDITABLE_VERSION`, `SOURCE_DATE_EPOCH`), `justfile` (`musl`
  recipe), `.cargo/config.toml` and `.cargo/lld-cc` (static-PIE link,
  path remapping), `rust-toolchain.toml`, `Cargo.toml` (release profile,
  mimalloc on musl), `packaging/Containerfile` (upstream's image),
  `packaging/config.toml` (paths and ports), `packaging/speculaire.service`
- Decisions, in `docs/decisions/`: D13 (musl static-PIE), D46 (mimalloc
  secure), D53 (root without capabilities), D57 (reproducible build),
  D112 (system trust roots), D157 (release image)
- Docs: `docs/operations.md`

## Decisions

- **A commit of `main`** (`ADD --checksum`): upstream has no release
  yet. The image's tag is the commit's first 8 characters, as
  `containers/silo-server`. Weekly, by hand: each commit is reviewed
  before nodes pull through it. After the first release, tags
  (AGENTS.md, Updates).
- **Upstream's release build, byte for byte:** upstream's build image
  (`rust:<tag>-alpine` at its digest), `cargo auditable build --release
  --locked --target <arch>-unknown-linux-musl -p speculaire` with
  `CARGO_TARGET_DIR=/target` and `SOURCE_DATE_EPOCH=0`, as `just musl`.
  The source at `/src` and the registry at `/usr/local/cargo`: the
  paths `.cargo/config.toml` remaps. mimalloc's secure mode and the
  static-PIE link come from the source, no flag to pass. At commit
  `3e1010cf`, the arm64 binary's SHA-256 is that of upstream CI's
  `speculaire-aarch64-unknown-linux-musl` artifact.
- **Alpine, not Debian:** upstream's build (D13): its lld links
  Alpine's musl objects. No Debian snapshot: nothing from the build
  stage but the binary and the CA bundle reaches the image.
- **The toolchain checked, not followed:** the rust image's tag is
  `rust-toolchain.toml`'s; `RUSTUP_TOOLCHAIN` keeps rustup from
  fetching that file's other components, so a commit moving it fails
  the build instead of building with another compiler.
- **cargo-auditable at upstream's version,** read from
  `build/Containerfile`: one pin, upstream's. The `.dep-v0` section is
  `just musl`'s check (`rust-audit-info` would be one more tool).
- **Built as UID 65532:** the crates' build scripts need no root.
- **Root at runtime, as upstream's (D53):** the runtime's sockets,
  content store and registry config, the kubelet's key and the NRI
  socket are root's. As their owner, root needs no capability.
- **The image holds the binary, Alpine's CA bundle and `LICENSE` and
  `NOTICE` (Apache-2.0).** The CA bundle: TLS to upstream registries
  and Sigstore's TUF repository uses the system's roots
  (`rustls-native-certs`, `crates/registry/src/connect.rs`); upstream's
  image has none. A node's own CA in its trust store (D112's `public`
  upstream) needs the host's bundle mounted over `/etc/ssl/certs`, or
  named by `SSL_CERT_FILE`. `NOTICE`: Apache-2.0 asks for it with the
  binary.
- **`/usr/bin/speculaire`, its entrypoint and no `CMD`:** upstream's
  image's, so the DaemonSet applies with only `image.*` changed.
- **No `VOLUME`, no `HEALTHCHECK`:** every path is a host path the
  DaemonSet mounts; the probes are the pod's HTTP ones (`/livez`,
  `/readyz` on 7482).
- **No upstream tests in the build:** upstream's CI runs them on the
  commit; the binary being upstream's, they hold for it.
