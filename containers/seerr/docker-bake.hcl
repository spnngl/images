# Seerr: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/seerr-team/seerr/tags (stable only:
# extractVersion skips any pre-release tag).
target "seerr" {
  name       = "seerr-debian${debian}"
  context    = "containers/seerr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=seerr-team/seerr extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.5.2", checksum = "18a90b4ed962cc56abc9087e305da5c18a3c7275" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("seerr", [base.version])
}
