# configarr: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
target "configarr" {
  name       = "configarr-debian${debian}"
  context    = "containers/configarr"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=raydak-labs/configarr extractVersion=^v(?<version>.+)$
      { version = "1.39.2", checksum = "c02056c7ef371fb12df18be6f976cd8ba0c3a921" },
    ]
    # The build's Node.js and the image's: upstream's major (AGENTS.md).
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "26.13.1-trixie-slim", digest = "sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc" },
    ]
    # Node 26 no longer includes Corepack; use upstream's Dockerfile version.
    corepack = [
      # renovate: datasource=npm depName=corepack
      { version = "0.36.0" },
    ]
    # Upstream's packageManager version (package.json).
    pnpm = [
      # renovate: datasource=npm depName=pnpm depType=automerge
      { version = "12.21.0" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    NODE_IMAGE    = "docker.io/library/node:${node.tag}@${node.digest}"
    # The tag's version, before its first "-".
    NODE_VERSION = split("-", node.tag)[0]
    COREPACK_VERSION = corepack.version
    PNPM_VERSION = pnpm.version
  }
  tags = tags("configarr", [base.version])
}
