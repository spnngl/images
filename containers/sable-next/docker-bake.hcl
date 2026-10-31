# sable-next: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/SableClient/sable-next/tags (stable only:
# extractVersion skips nightly-* and latest); the server's:
# https://github.com/static-web-server/static-web-server/tags. No pin for
# wasm-bindgen and wasm-opt: the build takes the releases upstream's
# .mise/mise.lock names, with their checksums.
target "sable-next" {
  name       = "sable-next-debian${debian}"
  context    = "containers/sable-next"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=SableClient/sable-next extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.2.0", checksum = "b29d8e7430beed05108129949b465221aff17b25" },
    ]
    sws = [
      # renovate: datasource=github-tags depName=static-web-server/static-web-server extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.44.1", checksum = "c5cbe67e91da91ccad838163cf9a034bf221a447" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    SWS_VERSION   = sws.version
    SWS_CHECKSUM  = sws.checksum
  })
  tags = tags("sable-next", [base.version])
}
