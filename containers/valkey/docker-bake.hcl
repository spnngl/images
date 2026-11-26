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
      { version = "9.2.0", checksum = "d23684e3ec302240754664417e3b99df23e8e4c9" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("valkey", [base.version])
}
