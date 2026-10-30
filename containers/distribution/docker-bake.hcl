# distribution: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/distribution/distribution/releases
target "distribution" {
  name       = "distribution-debian${debian}"
  context    = "containers/distribution"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=distribution/distribution extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.1.2", checksum = "3220848f15d9279c66a41aa0a257469e6aede1e9" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("distribution", [base.version])
}
