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
      { version = "RELEASE.2026-10-18T00-00-00Z", checksum = "0cd388c666f8211f552604ae73448a066e9c25ce" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("silo", [base.version])
}
