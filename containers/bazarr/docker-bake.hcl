# bazarr: what to build and with which versions (containers/AGENTS.md).
# Debian's FFmpeg and unrar come from the snapshot, not from here.
target "bazarr" {
  name       = "bazarr-debian${debian}"
  context    = "containers/bazarr"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=morpheus65535/bazarr versioning=semver extractVersion=^v(?<version>.+)$ depType=automerge
      { version = "1.6.2", checksum = "8c68f16a1e12f8e7985baeb73fb4199b5149108a" },
    ]
    uv = [
      # renovate: datasource=docker depName=ghcr.io/astral-sh/uv depType=automerge
      { version = "0.13.9", digest = "sha256:d3b601f0c7b118bc1753febf7c41cc80981df678445e0254284eecf84db79a7d" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    UV_VERSION    = uv.version
    UV_DIGEST     = uv.digest
  })
  tags = tags("bazarr", [base.version])
}
