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
      { version = "2.7.0.5723", checksum = "d65cb9fb442a8a3ded055d7027db9a08f519acb7908c7afe72175aa7c337783c" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Prowlarr/Prowlarr registryUrl=https://prowlarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "2.7.0.5723", checksum = "bd2dcc1d42f3ea37a247224bb4293e00ebd31e76f12abfca389c4260f7e0a71e" },
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
