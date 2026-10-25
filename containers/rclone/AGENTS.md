# rclone

rclone (sync, copy, serve and mount of cloud storage, Go) built with
Dalec from `spec.yml` like `containers/nftables-exporter`: one Debian
trixie package, the static binary, installed with Debian's `fuse3` for
`rclone mount`. Runtime contract (non-root, root for mount): the spec's
header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- Build natively only, as `containers/nftables-exporter`: Dalec's
  `gomod` generator fails under QEMU.
- The build's tests (upstream's `go test` of sync, operations and the
  local backend, then the server test) and the spec's tests are what
  automerges rest on: keep them.

## Updates

Renovate follows the repository's tags, minor and patch automerged once
CI passes: the build runs upstream's tests of what deletes or
overwrites data. A major waits for review. What changed:
`https://github.com/rclone/rclone/compare/v<old>...v<new>`; check the
build against `bin/cross-compile.go`. On `go.mod requires go >= ...` in
CI, bump `golang-<version>-go` in the spec. A checksum-only update means
upstream moved the tag.
