# rapx

RAPx (static analyzer for Rust, a rustc driver) built from its crates.io
release, on `gcr.io/distroless/cc-debian13`, with the Rust nightly it is
built against and the C toolchain cargo links with. Runs `cargo rapx` on
a mounted crate. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/local/bin/cargo", "rapx"]`: arguments are
  `cargo rapx`'s (`check -f`, `verify`, `analyze dot-mir`...).
- **Lockstep**: `NIGHTLY_VERSION` is the date of the RAPx release
  (`BASE_VERSION`), as a release builds on the nightlies of its time; a
  newer nightly fails in `cargo auditable install`. Renovate moves both
  in one PR.
- The build stage installs the toolchain twice: full (rustc-dev,
  rust-src) to build, minimal for the image.
- The image keeps no shell. The `smoke` stage tests it with busybox's
  `ash` and `grep`, and the last stage needs `smoke`'s marker file: every
  build runs the tests.
- `smoke-test/` holds copies of RAPx's test cases, each with a comment
  naming its source path. When an upgrade changes RAPx's output, change
  the assertions in `smoke`.
- Debian's packages come through the `closure` stage with their dpkg
  status, minus what distroless' base has. A package added to its install
  list lands in the image with its dependencies.
- The build stage compiles as UID 65532 (only packages and the
  toolchain install as root): its cache ids end in `-65532`.

## Updates

Renovate moves the crate (checksum from crates.io) and the nightly (the
release's publish date) in one pull request, proposed on Saturday, and
automerges it once the build and `smoke` pass. A failing `smoke` means
RAPx's output changed: update its assertions (Rules), done when the
build passes. When rustup finds no nightly of the release's date (a
day Rust skipped), set `NIGHTLY_VERSION` to the day before.
