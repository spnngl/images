# spegel: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/spegel-org/spegel/releases
target "spegel" {
  name       = "spegel-debian${debian}"
  context    = "containers/spegel"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=spegel-org/spegel extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.8.1", checksum = "7e2e042fa5a6858276b12bbd0be586b788dfa121" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("spegel", [base.version])
}
