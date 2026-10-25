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
      { version = "6.4.4.10685", checksum = "a1d726129535e739d4efaf93b5fdd771bb1c78349f55ceac70e365e37b5a12a3" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Radarr/Radarr registryUrl=https://radarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "6.4.4.10685", checksum = "8bf3c336ebe03acb061a6162fa36499268095ea5e5140362faf49701588dca96" },
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
