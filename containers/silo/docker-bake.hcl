# silo: what to build and with which versions (containers/AGENTS.md).
# Tags: https://github.com/pgsty/silo/tags
target "silo" {
  name       = "silo-debian${debian}"
  context    = "containers/silo"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=pgsty/silo depType=automerge-all
      { version = "RELEASE.2026-10-15T00-00-00Z", checksum = "7a3ca0f82100cce06289a465f54139da2639f642" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("silo", debian, [base.version])
}
