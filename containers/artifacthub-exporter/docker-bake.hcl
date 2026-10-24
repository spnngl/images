# artifacthub-exporter: what to build and with which versions
# (containers/AGENTS.md).
# Tags: https://github.com/spnngl/artifacthub-exporter/tags
target "artifacthub-exporter" {
  name       = "artifacthub-exporter-debian${debian}"
  context    = "containers/artifacthub-exporter"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=spnngl/artifacthub-exporter extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.1.0", checksum = "bdde95a25d11fda2b73272aeecff1837775ff2f7" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("artifacthub-exporter", [base.version])
}
