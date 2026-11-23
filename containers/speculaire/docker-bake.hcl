# speculaire: what to build and with which versions (containers/AGENTS.md).
# No debian matrix and no Debian arguments: the build stage is Alpine's
# (upstream's build image), the binary is static (REFERENCES.md).
target "speculaire" {
  name       = "speculaire"
  context    = "containers/speculaire"
  dockerfile = "Containerfile"
  matrix = {
    # Upstream has no release yet: main, at a commit (REFERENCES.md).
    base = [
      # renovate: datasource=git-refs depName=spnngl/speculaire packageName=https://github.com/spnngl/speculaire
      { version = "main", checksum = "3e1010cf555579c79ffa6859a8accd61bb67a11c" },
    ]
    # The toolchain of upstream's rust-toolchain.toml, which the build
    # checks; the tag stays (extractVersion matches it only), Renovate
    # moves the digest. A new toolchain: AGENTS.md, Updates.
    rust = [
      # renovate: datasource=docker depName=rust-1.99.1-alpine packageName=docker.io/library/rust extractVersion=^(?<version>1\.99\.1-alpine)$
      { tag = "1.99.1-alpine", digest = "sha256:44819b27be4c97b0e4d7203bd2e02c4820f97700211b6a37fb4c246a2de59383" },
    ]
  }
  args = {
    # The commit, 8 characters: the image's version label.
    BASE_VERSION  = substr(base.checksum, 0, 8)
    BASE_CHECKSUM = base.checksum
    RUST_TAG      = rust.tag
    RUST_DIGEST   = rust.digest
  }
  tags = tags("speculaire", [substr(base.checksum, 0, 8)])
}
