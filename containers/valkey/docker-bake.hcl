# Valkey: what to build and with which versions (containers/AGENTS.md).
# The latest release line only. Releases:
# https://github.com/valkey-io/valkey/releases
target "valkey" {
  name       = "valkey-debian${debian}"
  context    = "containers/valkey"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=valkey-io/valkey extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "9.1.3", checksum = "29173b67508b2de4c0f0ed551f3b47cf19fc3ca8" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("valkey", [base.version])
}
