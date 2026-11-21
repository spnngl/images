# Angos: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/project-angos/angos/tags
target "angos" {
  name       = "angos-debian${debian}"
  context    = "containers/angos"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=project-angos/angos extractVersion=^v(?<version>\d+\.\d+\.\d+)$
      { version = "1.13.0", checksum = "391787c8b7b50c8f64a35bb53db082678471b08e" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("angos", [base.version])
}
