# radarr: what to fetch and with which versions (containers/AGENTS.md).
# Tags name Radarr's version alone. One Debian release: the build stage
# installs packages from the snapshot.
#
# Upstream's self-contained release archive of each platform, and its
# sha256: the Servarr update feed (custom datasource `servarr`,
# renovate.json5) lists both for every release, so Renovate hashes
# nothing. Both entries move together: same dependency name, same
# version, so one PR; the build fails on two versions.
target "radarr" {
  name       = "radarr-debian${debian}"
  context    = "containers/radarr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.servarr depName=Radarr/Radarr registryUrl=https://radarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=x64 versioning=loose depType=automerge
      { version = "7.0.3.10918", checksum = "1737e72150ea991c8f224fcf529c419b7e6c567ba672cbf27a61f11c9a51fe8e" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Radarr/Radarr registryUrl=https://radarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "7.0.3.10918", checksum = "79c97999edd13bd34ee0f2cdb82de659f09daffda3be7548e07aedda56204538" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION        = base.version
    BASE_CHECKSUM_AMD64 = base.checksum
    BASE_VERSION_ARM64  = base_arm64.version
    BASE_CHECKSUM_ARM64 = base_arm64.checksum
  })
  tags = tags("radarr", [base.version])
}
