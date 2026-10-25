# Memcached: what to build and with which versions (containers/AGENTS.md).
# The latest release only. Releases: https://github.com/memcached/memcached/wiki/ReleaseNotes
target "memcached" {
  name       = "memcached-debian${debian}"
  context    = "containers/memcached"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=memcached/memcached extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.6.45", checksum = "2d51e364799bc9698bd4b11728ea978cea12da6e" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("memcached", [base.version])
}
