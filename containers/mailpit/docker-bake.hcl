# mailpit: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/axllent/mailpit/releases
target "mailpit" {
  name       = "mailpit-debian${debian}"
  context    = "containers/mailpit"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=axllent/mailpit extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.33.0", checksum = "364916b15e80a8bac1e7b0ab66a4f2b3d7d745c2" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mailpit", [base.version])
}
