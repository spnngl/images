# prowlarr: what to fetch and with which versions (containers/AGENTS.md).
# Tags name Prowlarr's version alone. One Debian release: the build stage
# installs packages from the snapshot.
#
# Upstream's self-contained release archive of each platform, and its
# sha256: the Servarr update feed (custom datasource `servarr`,
# renovate.json5) lists both for every release, so Renovate hashes
# nothing. Both entries move together: same dependency name, same
# version, so one PR; the build fails on two versions.
target "prowlarr" {
  name       = "prowlarr-debian${debian}"
  context    = "containers/prowlarr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.servarr depName=Prowlarr/Prowlarr registryUrl=https://prowlarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=x64 versioning=loose depType=automerge
      { version = "3.1.0.5799", checksum = "e9c66fd3d2c5e94ca51e2495eb9e99ee16004dc396cac4e74905d1408fe31767" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Prowlarr/Prowlarr registryUrl=https://prowlarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "3.1.0.5799", checksum = "1e74262cf955ee60b8091d100a109d66402e5786ede5f3b68fa77347d562174a" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION        = base.version
    BASE_CHECKSUM_AMD64 = base.checksum
    BASE_VERSION_ARM64  = base_arm64.version
    BASE_CHECKSUM_ARM64 = base_arm64.checksum
  })
  tags = tags("prowlarr", [base.version])
}
