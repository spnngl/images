# nftables-exporter: what to build and with which versions
# (containers/AGENTS.md). Dalec spec: no containerfile_args, Dalec fails
# on an undeclared one.
# Tags (upstream publishes no GitHub releases):
# https://github.com/metal-stack/nftables-exporter/tags
target "nftables-exporter" {
  name       = "nftables-exporter-debian${debian}"
  context    = "containers/nftables-exporter"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=metal-stack/nftables-exporter extractVersion=^v(?<version>\d+\.\d+\.\d+)$
      { version = "0.4.5", checksum = "a11a119bdc67e43a9cd4e21ef400e0be6048ed92" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  }
  tags = tags("nftables-exporter", debian, [base.version])
}
