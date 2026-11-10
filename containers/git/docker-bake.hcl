# git: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/git/git/tags
# No debian matrix and no Debian arguments: the build stage is Alpine's
# (its FROM line, followed by Renovate's dockerfile manager), the binaries
# are static (containers/git/REFERENCES.md).
# OpenSSH's version is its tag (V_10_6_P1), what Renovate's regex
# versioning reads; the Containerfile derives what `ssh -V` prints.
target "git" {
  name       = "git"
  context    = "containers/git"
  dockerfile = "Containerfile"
  matrix = {
    base = [
      # renovate: datasource=github-tags depName=git/git extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.56.1", checksum = "03b41523c576f26ad34085378717a0c1b287470f" },
    ]
    openssh = [
      # renovate: datasource=github-tags depName=openssh/openssh-portable versioning=regex:^V_(?<major>\d+)_(?<minor>\d+)_P(?<patch>\d+)$ depType=automerge
      { version = "V_10_6_P2", checksum = "d449e662b6b8b8cb20e852d8084c269af1c5e8f1" },
    ]
  }
  args = {
    BASE_VERSION     = base.version
    BASE_CHECKSUM    = base.checksum
    OPENSSH_VERSION  = openssh.version
    OPENSSH_CHECKSUM = openssh.checksum
  }
  tags = tags("git", [base.version])
}
