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
      { version = "0.13.7", digest = "sha256:96f40d3904aad8d0bd010539001d36c8e2188b981e1334471a90c4a1d93bb490" },
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
