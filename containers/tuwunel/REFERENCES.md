# tuwunel: references

## Sources

- Upstream: `github.com/matrix-construct/tuwunel` at tag
  `v<BASE_VERSION>`:
  - `docker/bake.hcl`: the release image (`docker`, `static`, `install`
    targets), the feature sets (`cargo_feat_sets`), the static link
    (`static_rustflags`, `static_libs`)
  - `docker/Dockerfile.cargo`: `CXXSTDLIB=""` and its reason
  - `docker/Dockerfile.smoketest`: the `-Otest='["smoke"]'` self-test
  - `.github/workflows/publish.yml`: what is published (`release`,
    `stable`, `all`)
  - `Cargo.toml`, `src/main/Cargo.toml`: profile, features, license,
    MSRV; `rust-toolchain.toml`
  - `src/core/config/mod.rs`, `tuwunel-example.toml`: configuration
  - `src/main/health.rs`: `--health-check`
  - `src/core/info/version.rs`, `src/macros/git.rs`: `--version`
- RocksDB bindings: `github.com/matrix-construct/rust-rocksdb` at the
  `rev` of the tag's `Cargo.toml` (`librocksdb-sys/build.rs`)
- Docs: <https://tuwunel.chat>; in the source, `docs/deploying/`
  (`container-security.md`, `docker.md`, `alpine.md`)

## Decisions

- **Static glibc binary, not musl:** upstream's release image is built
  that way. RocksDB is C++ and Debian has no musl libstdc++; on musl,
  jemalloc is prefixed and RocksDB's allocations bypass it
  (`docs/deploying/alpine.md`).
- **`CXXSTDLIB=""` and the `-l:lib*.a` arguments:** rust-rocksdb's build
  emits a dynamic `stdc++`, which leaves unresolved relocations in a
  static binary with no loader (`docker/Dockerfile.cargo`). The C++
  runtime, libc, libm and liburing come from their archives instead.
- **`--target` given:** `RUSTFLAGS` then skip build scripts and proc
  macros, which must stay dynamic to load libclang (bindgen).
- **gcc, not clang:** upstream compiles with clang and rust-lld. The
  `lto` feature of rust-rocksdb only adds `-flto` under clang
  (`build.rs`), so with gcc RocksDB is not LTO'd: no bitcode objects, no
  `ld.lld`. The performance cost is unmeasured.
- **`RUSTUP_TOOLCHAIN=${RUST_VERSION}`:** the base image's toolchain.
  Upstream's `rust-toolchain.toml` pins an MSRV channel with
  rust-analyzer, clippy and four targets that rustup would download.
  A newer stable is what upstream's `stable` builds use.
- **Features `all`:** what upstream publishes, so upstream's docs
  (LDAP, direct TLS, Sentry) apply. `tokio_console` and `tuwunel_mods`
  need `--cfg tokio_unstable` and `--cfg tuwunel_mods`, set on nightly
  only (`docker/bake.hcl`): compiled in, inactive, as upstream's image.
- **`x86-64-v2` on amd64:** RocksDB's `build.rs` follows the target
  features and enables SSE4.2 (hardware CRC32C); the default x86_64
  target has none and warns `compiling without SSE4.2: CRC will be
  slow`. Upstream's image is v1 (and builds v2 to v4 variants). Every
  x86_64 CPU since ~2009 has SSE4.2.
- **`cargo auditable`:** embeds the crate list in the binary: without
  it, the SBOM and the scans see no Rust dependency.
- **Built and tested as UID 65532:** the crates' build scripts and the
  test server run without root and can't change the source (root's).
  `CARGO_HOME` and `RUSTUP_HOME` are set; `HOME=/tmp` is for git
  (rust-rocksdb's submodule checkout). A cache keeps the owner it was
  created with: hence ids of their own.
- **No `.git` in the source:** the version is the crate's
  (`CARGO_PKG_VERSION`) when `git describe` fails.
- **Server test in the build stage:** `scratch` has no shell to run a
  server in the background. `-Otest=["smoke"]` upstream only starts and
  stops it: the test also writes through the API and reopens the
  database, which is what a release can break. Registration by token and
  `allow_federation=false`: no key fetch from other servers. JSON read
  with `sed`: no `jq` for one test.
- **Not root, unlike upstream's compose files:** every port is above
  1024 and the server needs no privilege (`container-security.md`).
  The state folder is 65532's in the image, so a new named volume is
  writable; a bind mount needs that owner.
- **`TUWUNEL_ADDRESS=0.0.0.0`:** the default is loopback, unreachable
  from outside a container (upstream's compose files set the same). A
  single address: one that is set must bind or the server refuses to
  start (`src/core/config/mod.rs`), `::` is dual-stack on Linux and
  collides with `0.0.0.0`, and fails where IPv6 is off.
- **No `TUWUNEL_DATABASE_PATH`:** the default is `/var/lib/tuwunel`.
- **Debian's CA bundle:** federation, URL previews, LDAP and Sentry use
  TLS with public CAs (`rustls-platform-verifier` reads the system
  path); upstream's image has the same file.
- **No config in the image:** it is the deployment's (`server_name`
  cannot be changed once set).
- **No `HEALTHCHECK`, no `CMD`:** upstream's `HEALTHCHECK` is
  `tuwunel --health-check` with a 30 minute start period (a database
  migration at startup): Kubernetes ignores the instruction, so the
  probe is documented for exec probes instead. The server needs no
  default arguments.
- **`--pids-limit` and io_uring:** a host with many cores can exceed a
  runtime's default task limit at startup, and the default seccomp
  profile blocks io_uring (the database falls back). Both in
  `docs/deploying/container-security.md`, noted in the Containerfile
  header.
