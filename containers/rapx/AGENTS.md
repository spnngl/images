# rapx

RAPx (static analyzer for Rust, a rustc driver) built from its crates.io
release, on `gcr.io/distroless/cc-debian13`, with the Rust nightly it is
built against and the C toolchain cargo links with. Runs `cargo rapx` on
a mounted crate. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/local/bin/cargo", "rapx"]`: arguments are
  `cargo rapx`'s (`check -f`, `verify`, `analyze dot-mir`...).
- **Lockstep**: RAPx's version and `NIGHTLY_VERSION` move together.
  A release builds on the nightlies of its time; a newer nightly fails
  in `cargo auditable install`.
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

Renovate moves the crate (checksum from crates.io) and the nightly (dates
from Rust's manifests list) in one pull request, proposed on Saturday,
and automerges it once the build and `smoke` pass.

When the build fails on lockstep, set `NIGHTLY_VERSION` to the date of
RAPx's release (crates.io, `Versions`), keeping RAPx's version Renovate's.
Done when the build and `smoke` pass.
