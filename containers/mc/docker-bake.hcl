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
      { version = "RELEASE.2026-10-25T00-00-00Z", checksum = "dcc78d506f94e7c2323b642d48fbb600664f0586" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mc", [base.version])
}
