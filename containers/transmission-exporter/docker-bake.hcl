# transmission-exporter: what to build and with which versions
# (containers/AGENTS.md).
# Tags: https://github.com/spnngl/transmission-exporter/tags
target "transmission-exporter" {
  name       = "transmission-exporter-debian${debian}"
  context    = "containers/transmission-exporter"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=spnngl/transmission-exporter extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.5.0", checksum = "1a956fbe835e38d431726815c5383c10072e7907" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("transmission-exporter", [base.version])
}
