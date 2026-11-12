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
      { version = "RELEASE.2026-11-09T00-00-00Z", checksum = "e1d4cc5abfe00b674eb36347399e7398990be467" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mc", [base.version])
}
