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
      { version = "1.12.4", checksum = "c4cad324360967746fabf3ebf9528601bede7ae6" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("angos", [base.version])
}
