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
      { version = "9.1.2", checksum = "7f1dffedff6de73058b2c2a389422b6ecd56c8fb" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("valkey", [base.version])
}
