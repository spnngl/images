# rapx

RAPx (static analyzer for Rust, a rustc driver) built from its crates.io
release, on `gcr.io/distroless/cc-debian13`, with the Rust nightly it is
built against and the C toolchain cargo links with. Runs `cargo rapx` on
a mounted crate. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/local/bin/cargo", "rapx"]`: arguments are
  `cargo rapx`'s (`check -f`, `verify`, `analyze dot-mir`...).
- The nightly's date (`NIGHTLY_VERSION`) and RAPx's version move
  together: RAPx reads rustc's internals, and a release supports the
  nightlies of its time. A nightly that RAPx can't build against fails the
  build in `cargo auditable install`.
- Nothing from rustc-dev or rust-src reaches the image: the build stage
  installs the toolchain twice, the second time minimal.
- No shell in the image. Tests run in the `smoke` stage (busybox's `ash`
  and `grep`, copied to `/bin`), and the last stage needs that
  stage's marker file, so every build runs them.
- `smoke-test/` crates are copies of RAPx's own test cases, each with a
  comment naming its path. An upgrade that changes RAPx's output changes
  the assertions in `smoke`, never the other way round.
- Packages of Debian's come through the `closure` stage with their dpkg
  status, minus what distroless' base has. A package added to the
  install list there lands in the image with its dependencies.
- The build stage compiles as UID 65532 (only packages and the
  toolchain install as root): its cache ids end in `-65532`.

## Updates

Renovate moves RAPx's crate (crates.io, with its checksum) and the
nightly (dates in Rust's manifests list) in one pull request, proposed
on Saturday, and automerges it once the build and `smoke` pass. When the
build fails because the newest nightly is newer than what RAPx's newest
release supports, set `NIGHTLY_VERSION` by hand to the date RAPx's
release was published (crates.io page, `Versions`), and keep RAPx's
version Renovate's.
