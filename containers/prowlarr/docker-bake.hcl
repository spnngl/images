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
      { version = "2.6.5.5623", checksum = "c0824e9f0e9c79e085882f6143041be5c2cde0519baa59e9477d9e4dcbe1b5e3" },
    ]
    base_arm64 = [
      # renovate: datasource=custom.servarr depName=Prowlarr/Prowlarr registryUrl=https://prowlarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=arm64 versioning=loose depType=automerge
      { version = "2.6.5.5623", checksum = "6552ac286d8a1213f99779daac685cc283d69fa6ad3144d811af0289ee5f5656" },
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
