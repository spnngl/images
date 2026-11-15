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
      { version = "RELEASE.2026-11-12T00-00-00Z", checksum = "44e848fedf8cec3d8c0da4b1aa8422390a2b7a8b" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("silo", [base.version])
}
