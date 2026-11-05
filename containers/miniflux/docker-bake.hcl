# miniflux: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/miniflux/v2/releases. Each has two tags on
# one commit, <x.y.z> and v<x.y.z> (Go's module tag): the first is the
# release's (upstream's CI builds on it), the second is skipped.
target "miniflux" {
  name       = "miniflux-debian${debian}"
  context    = "containers/miniflux"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=miniflux/v2 extractVersion=^(?<version>\d+\.\d+\.\d+)$
      { version = "2.3.5", checksum = "faecfa2fac61a91f4f69550bb1afd506c4b51749" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("miniflux", [base.version])
}
