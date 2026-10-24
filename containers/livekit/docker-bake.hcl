# LiveKit server: what to build and with which versions
# (containers/AGENTS.md).
# Releases: https://github.com/livekit/livekit/releases
target "livekit" {
  name       = "livekit-debian${debian}"
  context    = "containers/livekit"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-releases depName=livekit/livekit extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.13.10", checksum = "e5655ac20267fa5005dccaf3f0e3bfc3ea688c07" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("livekit", [base.version])
}
