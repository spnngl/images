# flux-toolbox: what to fetch and with which versions (containers/AGENTS.md).
# Tags name flux's version alone: another tool's update rebuilds the same
# tag. git, busybox, kubectl and helm come from this repository's images,
# the Containerfile's FROM lines (Renovate's dockerfile manager).
# No debian matrix and no Debian arguments: the binaries are upstream's
# static release builds, on the git image, and sops, static, built on
# golang's image, which installs no Debian package.
#
# Each entry but sops' is a GitHub release tag, as Renovate's
# github-release-attachments datasource looks it up (releases/tags/<tag>),
# and the sha256 of the release's checksum file, which it rewrites with
# the version (containers/flux-toolbox/REFERENCES.md). The build gets the
# version without the tag's prefix.
target "flux-toolbox" {
  name       = "flux-toolbox"
  context    = "containers/flux-toolbox"
  dockerfile = "Containerfile"
  matrix = {
    base = [
      # renovate: datasource=github-release-attachments depName=fluxcd/flux2 depType=automerge
      { version = "v2.10.1", checksum = "f7c5d1887d6e589b2bcc193bc823ff2a6413999ee8014caab608f4c3a4bdd20d" },
    ]
    flux_operator = [
      # renovate: datasource=github-release-attachments depName=controlplaneio-fluxcd/flux-operator depType=automerge
      { version = "v0.62.1", checksum = "3fe087eee8c0d778d23cc3bc80d10cda68b69d5209924b6dec28cf8770c2ad1d" },
    ]
    flux_schema = [
      # renovate: datasource=github-release-attachments depName=fluxcd/flux-schema depType=automerge
      { version = "v0.18.0", checksum = "d802ace4fd8ed45d758d46d28f8c75b540036bedc71a77481805725a2ce52ae6" },
    ]
    # Tags kustomize/v*: api/, kyaml/ and cmd/config/ are its libraries,
    # whose tags the versioning leaves out.
    kustomize = [
      # renovate: datasource=github-release-attachments depName=kubernetes-sigs/kustomize versioning=regex:^kustomize/v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$ depType=automerge
      { version = "kustomize/v5.8.3", checksum = "04c0f148d8c9af726cabbcd7c6e7f943a88ca971f66eada9855ec1bfe1e1b982" },
    ]
    nushell = [
      # renovate: datasource=github-release-attachments depName=nushell/nushell depType=automerge
      { version = "0.117.0", checksum = "b7261d7a734d4382f43389f7d35a2578883e51f0bb6bb462a1091aa75d39b839" },
    ]
    # Built from its tag, not a release binary: the version and its
    # commit, as containers/kustomize's, checked by ADD --checksum.
    sops = [
      # renovate: datasource=github-tags depName=getsops/sops extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.13.3", checksum = "26e2f4784ca61353082c32dbd987c25eda086dc9" },
    ]
  }
  args = {
    BASE_VERSION           = trimprefix(base.version, "v")
    BASE_CHECKSUM          = base.checksum
    FLUX_OPERATOR_VERSION  = trimprefix(flux_operator.version, "v")
    FLUX_OPERATOR_CHECKSUM = flux_operator.checksum
    FLUX_SCHEMA_VERSION    = trimprefix(flux_schema.version, "v")
    FLUX_SCHEMA_CHECKSUM   = flux_schema.checksum
    KUSTOMIZE_VERSION      = trimprefix(kustomize.version, "kustomize/v")
    KUSTOMIZE_CHECKSUM     = kustomize.checksum
    NUSHELL_VERSION        = nushell.version
    NUSHELL_CHECKSUM       = nushell.checksum
    SOPS_VERSION           = sops.version
    SOPS_CHECKSUM          = sops.checksum
  }
  tags = tags("flux-toolbox", [trimprefix(base.version, "v")])
}
