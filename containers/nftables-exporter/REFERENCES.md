# nftables-exporter: references

## Sources

- Upstream: `github.com/metal-stack/nftables-exporter` at tag
  `v<BASE_VERSION>` (`options.go` for the options); no GitHub releases
- Dalec: `containers/sabnzbd/REFERENCES.md`

## Decisions

- **Dalec, not a static binary on `scratch`:** the exporter runs `nft
  -j -t list ruleset` on every scrape, and nft needs its libraries.
  trixie's nftables (1.1.3) is enough: set `count` metrics need nft
  1.1.7 and an unreleased exporter.
- **Go from trixie-backports, build only** (`extra_repos`, `envs:
  [build]`): trixie's golang-go is older than `go.mod` requires.
  Renovate follows backports' golang-go through Repology: its deb
  datasource can't read backports' `Packages.xz`. Go modules come from
  Dalec's `gomod` generator, pinned by `go.sum`.
- **Native builds only:** Dalec runs the `gomod` generator in the build
  platform's root filesystem without its `PATH`. CI builds each
  platform on its own runner.
- **Loopback, not upstream's `:9630`:** it runs in the host network, and
  the rules (comments, addresses, ports) would be on every interface.
- **Root with `NET_ADMIN`:** nft reads the ruleset over netlink with
  `CAP_NET_ADMIN`, and a non-root process loses it when it execs nft.
  Checked: as UID 65532 with `NET_ADMIN`, `nftables_up` is 0. The
  spec's header has the full reasoning.
- **Upstream's unit tests in the build** (no network or nft needed):
  with the spec's tests, the only check of an automerged Go update.
