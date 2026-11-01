# rapx: references

## Sources

- Upstream: `github.com/safer-rust/RAPx`, released as the crate `rapx`
  (`https://crates.io/crates/rapx`, version `<BASE_VERSION>`): `README.md`
  (commands), `rapx/src/bin/cargo-rapx` (the cargo subcommand),
  `rapx/build.rs` (what it reads from the nightly), `rapx/tests/` (test
  cases and assertions), `Dockerfile` (upstream's build: Ubuntu, nightly
  by rustup, `./install.sh`).
- The crate's own commit: `.cargo_vcs_info.json` in the crate.
  Upstream has no git tag; the smoke-test crates come from there.
- Nightlies: `https://static.rust-lang.org/manifests.txt`, one
  `dist/<date>/channel-rust-nightly.toml` per nightly.

## Decisions

- **The crates.io crate, not the git repository:** upstream has no tag, a
  release is a published version, and crates.io gives its checksum, which
  `ADD --checksum` verifies. `cargo install --locked` uses the crate's
  `Cargo.lock`.
- **A dated nightly, from the same date as the release:** `rapx/build.rs`
  detects rustc's internals by grepping the sysroot's source and adapts
  to the nightlies of its time, so the build is only reproducible with a
  pinned date. Renovate's built-in `crate` datasource gives no checksum,
  and nothing lists nightlies: two custom datasources
  (`renovate.json5`), in one group.
- **rustc-dev and rust-src in the build only:** `rapx/build.rs` and
  `rustc_private` need them (1.2 GB with them, 0.5 GB without). A
  component can't be removed in place, as rustup renames folders across
  layers: a second, minimal install under `RUSTUP_HOME=/tmp/rustup`.
- **Toolchain in `/usr/local`, rpath `$ORIGIN/../lib`:** `rapx` and
  `cargo-rapx` link `librustc_driver`, which a nightly's sysroot holds in
  `lib/`; the rpath finds it without `LD_LIBRARY_PATH`, which a
  hardened runtime may not set. `-L native=<sysroot>/lib` at build:
  libLLVM is a link script there, outside rustc's search path.
- **Real `cargo` and `rustc`, no rustup:** `cargo-rapx` sets itself as
  `RUSTC_WRAPPER` and runs `rustc` and `rapx` from `PATH`: the image has
  both, next to each other. Only the host target: no rustup, so no
  `--target`.
- **Distroless base and a closure of Debian's packages:** cargo links
  build scripts and proc-macros with `cc`; RAPx runs `dot`, `mkdir` and
  `rm`; `z3` is dynamic. Everything is copied with its dpkg status, so
  scanners see it, as `containers/bazarr` does. A full Debian base would
  carry a shell, apt and the rest.
- **gcc and libc6-dev only, no g++, make or pkg-config:** what linking
  Rust needs; a crate with C or C++ sources of its own needs a different
  image.
- **Graphviz with its postinst products:** `cc` (update-alternatives),
  the plugin registry `config*` (without it `dot` tries to write it and a
  non-root user can't) and fontconfig's links and cache are made by
  postinst scripts, so the closure stage copies them by path.
- **busybox in the smoke stage only:** no shell in the image, but the
  tests need one. only `ash` and `grep` are copied, by name, into `/bin`, so `mkdir`,
  `rm`, `dot` and `cc` are the image's own (and hadolint, which knows
  `/bin/ash` by name, checks `pipefail`).
- **`CARGO_HOME` is `/var/cache/cargo`, a volume:** the user has no home,
  and a crate's dependencies are fetched from crates.io on first use. The
  folder is 65532's in the image, so a new named volume is writable.
- **`/src` is the working directory:** `cargo rapx` runs `cargo check`
  and `cargo clean` there, and RAPx writes `MIR_dot_graph/` and
  `SafetyFlow/` in it.
- **Smoke crates `uaf_1` and `mut_ptr_read_precond`:** the smallest of
  RAPx's cases for `check -f` and `verify`; their assertions are the ones
  of `rapx/tests/tests.rs`. `analyze dot-mir` covers Graphviz.
- **`cargo auditable`** embeds the crate list in `rapx` and `cargo-rapx`:
  without it, SBOM and scans see no Rust dependency.
- **MPL-2.0 text in `/usr/share/doc/rapx/`:** RAPx's license; the crate
  carries none, Debian's `common-licenses` does.
