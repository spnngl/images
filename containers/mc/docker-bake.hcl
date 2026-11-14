# mc: what to build and with which versions (containers/AGENTS.md).
# Tags: https://github.com/pgsty/mc/tags
target "mc" {
  name       = "mc-debian${debian}"
  context    = "containers/mc"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=pgsty/mc depType=automerge-all
      { version = "RELEASE.2026-11-12T00-00-00Z", checksum = "a37a9f054fba828a0bbbceb4e9ff247ccf09c28d" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mc", [base.version])
}
