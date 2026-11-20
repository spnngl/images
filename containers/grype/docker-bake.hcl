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
      { version = "0.122.0", checksum = "4419483072181b643c3efde0fd15b9113d88887f" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("grype", [base.version])
}
