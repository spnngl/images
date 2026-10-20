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
      { version = "2.56.0", checksum = "a018953688f1b10bddf91bff8747068f5f4746a4" },
    ]
    openssh = [
      # renovate: datasource=github-tags depName=openssh/openssh-portable versioning=regex:^V_(?<major>\d+)_(?<minor>\d+)_P(?<patch>\d+)$ depType=automerge
      { version = "V_10_6_P1", checksum = "a8c72b842423f0774f542d3c2197247c3dd28d74" },
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
