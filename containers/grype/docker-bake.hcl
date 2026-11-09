# grype: what to build and with which versions (containers/AGENTS.md).
# Tags: https://github.com/anchore/grype/tags
target "grype" {
  name       = "grype-debian${debian}"
  context    = "containers/grype"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=anchore/grype extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.121.2", checksum = "82d7a0ea911946b99343c672056867d372f9b319" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("grype", [base.version])
}
