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
      { version = "1.31.6", checksum = "a028b01f4a24b4b36bdad95b8e09e070ebf2bad4" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mailpit", [base.version])
}
