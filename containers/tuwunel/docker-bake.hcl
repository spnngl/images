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
      { version = "2.0.0", checksum = "a3feae1a26ec764ee88606c2c68b659a9b5fba8d" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("tuwunel", [base.version])
}
