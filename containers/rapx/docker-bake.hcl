# RAPx: what to build and with which versions (containers/AGENTS.md).
# Releases: https://crates.io/crates/rapx/versions
target "rapx" {
  name       = "rapx-debian${debian}"
  context    = "containers/rapx"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.crates-io depName=rapx registryUrl=https://crates.io/api/v1/crates/rapx/versions versioning=semver depType=automerge
      { version = "0.7.65", checksum = "9a210d0053a0a91a10367d6f9b858afdb58e4894e0a4fb7aa64f3759a57db439" },
    ]
    nightly = [
      # renovate: datasource=custom.rust-nightly depName=rust-nightly versioning=regex:^(?<major>\d{4})-(?<minor>\d{2})-(?<patch>\d{2})$ depType=automerge
      { version = "2026-10-29" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION    = base.version
    BASE_CHECKSUM   = base.checksum
    NIGHTLY_VERSION = nightly.version
  })
  tags = tags("rapx", [base.version])
}
