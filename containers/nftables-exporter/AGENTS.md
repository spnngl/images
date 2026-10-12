# nftables-exporter

Prometheus exporter of the host's nftables counters, sets, chains and
rules (Go), built with Dalec from `spec.yml` like `containers/sabnzbd`:
one Debian trixie package, installed with Debian's `nftables`. Runtime
contract (Kubernetes DaemonSet, root with `NET_ADMIN`, host network,
loopback): the spec's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Config `nftables_exporter.yaml` goes to `/etc/nftables_exporter.yaml`,
  the exporter's default `--config`: it exits without one.
- Build natively only: a cross build (QEMU) fails in Dalec's `gomod`
  generator with `exec: "sh": executable file not found in $PATH`.
- The build runs upstream's unit tests (`go test ./...`).

## Updates

Never automerged. Before merging, port upstream's `options.go` changes
(`https://github.com/metal-stack/nftables-exporter/compare/v<old>...v<new>`)
to `nftables_exporter.yaml`. `go.mod requires go >= ...` in CI: bump
`golang-<version>-go` in the spec. A checksum-only update means
upstream moved the tag.
