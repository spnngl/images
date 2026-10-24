# tuwunel

Tuwunel (Matrix homeserver, Rust, RocksDB) built from source, one static
glibc binary on `scratch`. Close to upstream's published image: same
paths (`/usr/bin/tuwunel`, `/var/lib/tuwunel`), Cargo features
(`all`) and static link, so upstream's docs apply. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/bin/tuwunel"]`: arguments are Tuwunel's.
- glibc, not musl, and `CXXSTDLIB=""` with the `-l:lib*.a` link
  arguments: the static link is upstream's (`docker/bake.hcl`,
  `static_rustflags`, `static_libs`). The build fails if the binary is
  dynamic.
- `RUSTUP_TOOLCHAIN=${RUST_VERSION}` (the base image's): without it
  rustup downloads upstream's `rust-toolchain.toml` toolchain.
- Cargo features are upstream's `all` set (`docker/bake.hcl`,
  `cargo_feat_sets`).
- amd64 builds for `x86-64-v2`: the image does not run on a CPU without
  SSE4.2. arm64 keeps the default baseline.
- `TUWUNEL_ADDRESS=0.0.0.0`: one address, never `["0.0.0.0", "::"]`
  (an address set must bind, and the pair collides).
- The build stage compiles and tests as UID 65532 (only packages install
  as root): its cache ids end in `-65532`.
- Probe: `["/usr/bin/tuwunel", "--health-check"]` as an exec probe, no
  shell or curl needed. No `HEALTHCHECK` instruction.

## Smoke tests

The build stage runs the server: `--version`, then registration by
token, a user, a room and a message through the client API, a graceful
stop, and the same database reopened with the message still there.
`tokio_console` and `tuwunel_mods` are compiled in and inactive (they
need cfg flags upstream sets on nightly only), so nothing tests them.

## Updates

Renovate follows upstream's GitHub tags. Patch and minor releases and
Rust bumps are automerged (the server test covers startup, an empty
database and a room round trip, not an upgrade from the previous
release's data). A major release is never automerged. Database
migrations are one-way: before merging any release, read its notes
(`https://github.com/matrix-construct/tuwunel/releases/tag/v<new>`);
merging changes the image tag, and a node stays on the old one until
moved. Each bump, by hand or from the PR:

- `docker/bake.hcl`'s `cargo_feat_sets.all` against the `--features`
  list of the Containerfile;
- `rust-toolchain.toml`'s `channel` (upstream's MSRV) against the base
  image's `rust:` tag: the tag must not be older.
