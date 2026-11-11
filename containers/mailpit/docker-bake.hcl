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
      { version = "1.33.1", checksum = "3bc38efc5c4687659b9099eb2c8d8f6e76113f11" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mailpit", [base.version])
}
