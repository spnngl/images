# flux-toolbox: what to fetch and with which versions (containers/AGENTS.md).
# Tags name flux's version alone: another tool's update rebuilds the same
# tag. git, busybox and kubectl come from this repository's images, the
# Containerfile's FROM lines (Renovate's dockerfile manager).
# No debian matrix and no Debian arguments: the binaries are upstream's
# static release builds, on the git image.
#
# Each entry is a GitHub release tag, as Renovate's
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
      { version = "v2.10.0", checksum = "4267dbab83ad0dab0570cf87f5af8392b862e9a6d23d57cb856601444f031788" },
    ]
    flux_operator = [
      # renovate: datasource=github-release-attachments depName=controlplaneio-fluxcd/flux-operator depType=automerge
      { version = "v0.62.0", checksum = "24e68016f25580e21cc5ce4d3e5315a02ee7a858e4c3e93c67547cad4c97dbe7" },
    ]
    # Tags kustomize/v*: api/, kyaml/ and cmd/config/ are its libraries,
    # whose tags the versioning leaves out.
    kustomize = [
      # renovate: datasource=github-release-attachments depName=kubernetes-sigs/kustomize versioning=regex:^kustomize/v(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)$ depType=automerge
      { version = "kustomize/v5.8.3", checksum = "04c0f148d8c9af726cabbcd7c6e7f943a88ca971f66eada9855ec1bfe1e1b982" },
    ]
    nushell = [
      # renovate: datasource=github-release-attachments depName=nushell/nushell depType=automerge
      { version = "0.116.1", checksum = "296b515aa8416a012ca444e40a0e7635266872cc99b8ab704e1bdc8fcb3dd0a6" },
    ]
  }
  args = {
    BASE_VERSION           = trimprefix(base.version, "v")
    BASE_CHECKSUM          = base.checksum
    FLUX_OPERATOR_VERSION  = trimprefix(flux_operator.version, "v")
    FLUX_OPERATOR_CHECKSUM = flux_operator.checksum
    KUSTOMIZE_VERSION      = trimprefix(kustomize.version, "kustomize/v")
    KUSTOMIZE_CHECKSUM     = kustomize.checksum
    NUSHELL_VERSION        = nushell.version
    NUSHELL_CHECKSUM       = nushell.checksum
  }
  tags = tags("flux-toolbox", [trimprefix(base.version, "v")])
}
