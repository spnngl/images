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
      { version = "RELEASE.2026-10-26T00-00-00Z", checksum = "0ceb298cdcd05f2ffdc4ea62d7d01a3666c3e8cc" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("mc", [base.version])
}
