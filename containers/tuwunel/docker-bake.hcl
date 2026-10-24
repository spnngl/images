# Tuwunel: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/matrix-construct/tuwunel/tags
target "tuwunel" {
  name       = "tuwunel-debian${debian}"
  context    = "containers/tuwunel"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=matrix-construct/tuwunel extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.9.4", checksum = "f473d9a4a8342514302884041e0ccfea1ad503fc" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("tuwunel", [base.version])
}
