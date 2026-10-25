# sonarr: what to fetch and with which versions (containers/AGENTS.md).
# Tags name Sonarr's version alone. One Debian release: the build stage
# installs packages from the snapshot.
#
# Upstream's self-contained release archive of each platform, and its
# sha256: the Servarr update feed (custom datasource `servarr`,
# renovate.json5) lists both for every release, so Renovate hashes
# nothing. Both entries move together: same dependency name, same
# version, so one PR; the build fails on two versions.
# Sonarr's feed answers for the version the client says it runs: without
# `version`, it lists what a 3.x install can update to (4.0.9.2244 at
# most); with 4.0.0.0, the 4.x releases, and later majors with
# `includeMajorVersion` (as Sonarr's updater asks).
target "sonarr" {
  name       = "sonarr-debian${debian}"
  context    = "containers/sonarr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.servarr depName=Sonarr/Sonarr registryUrl=https://services.sonarr.tv/v1/update/main/changes?version=4.0.0.0&os=linux&runtime=netcore&includeMajorVersion=true&arch=x64 versioning=loose depType=automerge
      { version = "4.0.20.3014", checksum = "1fc48544b5a3401b2fc3df8d0642c1e6a73a28e41a351169edd9cd8f54770db5" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Sonarr/Sonarr registryUrl=https://services.sonarr.tv/v1/update/main/changes?version=4.0.0.0&os=linux&runtime=netcore&includeMajorVersion=true&arch=arm64 versioning=loose depType=automerge
      { version = "4.0.20.3014", checksum = "bd93f7f06b8cb940da0814106d1293df12bf9199af0514e95b893f0c603fc7b9" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION        = base.version
    BASE_CHECKSUM_AMD64 = base.checksum
    BASE_VERSION_ARM64  = base_arm64.version
    BASE_CHECKSUM_ARM64 = base_arm64.checksum
  })
  tags = tags("sonarr", [base.version])
}
