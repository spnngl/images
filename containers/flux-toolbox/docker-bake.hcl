# flux-toolbox: what to fetch and with which versions (containers/AGENTS.md).
# Tags name flux's version alone: another tool's update rebuilds the same
# tag. git, busybox, kubectl and helm come from this repository's images,
# the Containerfile's FROM lines (Renovate's dockerfile manager).
# Debian: cocogitto's build stage, on rust's image, installs Debian
# packages from the snapshot; the other binaries are upstream's static
# release builds, on the git image, or sops and flate, static, built on
# golang's image, which installs none.
#
# Each entry but sops', flate's and cocogitto's is a GitHub release tag,
# as Renovate's github-release-attachments datasource looks it up
# (releases/tags/<tag>), and the sha256 of the release's checksum file,
# which it rewrites with the version
# (containers/flux-toolbox/REFERENCES.md). The build gets the version
# without the tag's prefix.
target "flux-toolbox" {
  name       = "flux-toolbox-debian${debian}"
  context    = "containers/flux-toolbox"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-release-attachments depName=fluxcd/flux2 depType=automerge
      { version = "v2.10.1", checksum = "f7c5d1887d6e589b2bcc193bc823ff2a6413999ee8014caab608f4c3a4bdd20d" },
    ]
    flux_operator = [
      # renovate: datasource=github-release-attachments depName=controlplaneio-fluxcd/flux-operator depType=automerge
      { version = "v0.63.1", checksum = "6ac4c4d5a4ae58d54d8ff7fb5d1a7f413abfd20f4f7bf4fd19ec1d1c20125a90" },
    ]
    flux_schema = [
      # renovate: datasource=github-release-attachments depName=fluxcd/flux-schema depType=automerge
      { version = "v0.18.0", checksum = "d802ace4fd8ed45d758d46d28f8c75b540036bedc71a77481805725a2ce52ae6" },
    ]
    kyverno = [
      # renovate: datasource=github-release-attachments depName=kyverno/kyverno depType=automerge
      { version = "v1.20.0", checksum = "b33755669f3337ff7d172f45382b55f0a96f39c87cf66c7f18274ef5cc414292" },
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
    # sops, flate and cocogitto: built from their tags, not release
    # binaries, each the version and its commit, as containers/kustomize's,
    # checked by ADD --checksum. cocogitto's tags: <version> are its
    # releases, cocogitto-<version> and cocogitto-dependency-resolver-*
    # its crates', which the extractVersion leaves out.
    cocogitto = [
      # renovate: datasource=github-tags depName=cocogitto/cocogitto extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "7.0.0", checksum = "055a9fa8db8ac8ce50074d50162b48b92e9d0c47" },
    ]
    flate = [
      # renovate: datasource=github-tags depName=home-operations/flate extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.8.0", checksum = "4e07f351352d235a335e5a1f0a088eab7ec40997" },
    ]
    sops = [
      # renovate: datasource=github-tags depName=getsops/sops extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.13.3", checksum = "26e2f4784ca61353082c32dbd987c25eda086dc9" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION           = trimprefix(base.version, "v")
    BASE_CHECKSUM          = base.checksum
    COCOGITTO_VERSION      = cocogitto.version
    COCOGITTO_CHECKSUM     = cocogitto.checksum
    FLATE_VERSION          = flate.version
    FLATE_CHECKSUM         = flate.checksum
    FLUX_OPERATOR_VERSION  = trimprefix(flux_operator.version, "v")
    FLUX_OPERATOR_CHECKSUM = flux_operator.checksum
    FLUX_SCHEMA_VERSION    = trimprefix(flux_schema.version, "v")
    FLUX_SCHEMA_CHECKSUM   = flux_schema.checksum
    KYVERNO_VERSION        = trimprefix(kyverno.version, "v")
    KYVERNO_CHECKSUM       = kyverno.checksum
    KUSTOMIZE_VERSION      = trimprefix(kustomize.version, "kustomize/v")
    KUSTOMIZE_CHECKSUM     = kustomize.checksum
    NUSHELL_VERSION        = nushell.version
    NUSHELL_CHECKSUM       = nushell.checksum
    SOPS_VERSION           = sops.version
    SOPS_CHECKSUM          = sops.checksum
  })
  tags = tags("flux-toolbox", [trimprefix(base.version, "v")])
}
