# buildkit: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/moby/buildkit/tags
# No debian matrix and no Debian arguments: the build stage is the golang
# image's, Alpine (its FROM line, followed by Renovate's dockerfile
# manager), the binaries are static (containers/buildkit/REFERENCES.md).
# runc, RootlessKit and shadow: the versions BuildKit's Dockerfile pins
# (RUNC_VERSION, ROOTLESSKIT_VERSION) or, for shadow, its own choice
# (REFERENCES.md); tracked on their own, a release of each is a rebuild.
# entitlements: the Containerfile's smoke test runs a daemon, which needs
# `security.insecure`; the builder must allow it (containers/AGENTS.md).
target "buildkit" {
  name         = "buildkit"
  context      = "containers/buildkit"
  dockerfile   = "Containerfile"
  entitlements = ["security.insecure"]
  matrix = {
    base = [
      # renovate: datasource=github-tags depName=moby/buildkit extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.34.2", checksum = "8c579433824224dc64a158cf8734495b6e2b186a" },
    ]
    runc = [
      # renovate: datasource=github-tags depName=opencontainers/runc extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.5.2", checksum = "29dd3dc2b13b4123162e5fe132504bb4b15569f1" },
    ]
    rootlesskit = [
      # renovate: datasource=github-tags depName=rootless-containers/rootlesskit extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.3.0", checksum = "888c3189e9cdf34dcdb19011e1c7c34eb94b5393" },
    ]
    shadow = [
      # renovate: datasource=github-tags depName=shadow-maint/shadow extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "4.20.3", checksum = "7188fbf46f397ab40d2e77d6f0bb8ebbe479cc0c" },
    ]
  }
  args = {
    BASE_VERSION         = base.version
    BASE_CHECKSUM        = base.checksum
    RUNC_VERSION         = runc.version
    RUNC_CHECKSUM        = runc.checksum
    ROOTLESSKIT_VERSION  = rootlesskit.version
    ROOTLESSKIT_CHECKSUM = rootlesskit.checksum
    SHADOW_VERSION       = shadow.version
    SHADOW_CHECKSUM      = shadow.checksum
  }
  tags = tags("buildkit", [base.version])
}
