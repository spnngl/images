# lidarr: what to fetch and with which versions (containers/AGENTS.md).
# Tags name Lidarr's version alone. One Debian release: the build stage
# installs packages from the snapshot.
#
# Upstream's self-contained release archive of each platform, and its
# sha256: the Servarr update feed (custom datasource `servarr`,
# renovate.json5) lists both for every release, so Renovate hashes
# nothing. Both entries move together: same dependency name, same
# version, so one PR; the build fails on two versions.
target "lidarr" {
  name       = "lidarr-debian${debian}"
  context    = "containers/lidarr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.servarr depName=Lidarr/Lidarr registryUrl=https://lidarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=x64 versioning=loose depType=automerge
      { version = "3.1.0.4875", checksum = "20f175aec2b908de2ae06b72544dae504efddb5db2a97ea4e36866de53bc2fa5" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Lidarr/Lidarr registryUrl=https://lidarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "3.1.0.4875", checksum = "ff58021d4b77b0310c90413abd4f3036cfd50312fe7b192e9d688d482e4cbf36" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION        = base.version
    BASE_CHECKSUM_AMD64 = base.checksum
    BASE_VERSION_ARM64  = base_arm64.version
    BASE_CHECKSUM_ARM64 = base_arm64.checksum
  })
  tags = tags("lidarr", [base.version])
}
