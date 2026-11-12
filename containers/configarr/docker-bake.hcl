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
      { version = "1.39.1", checksum = "deaeba18dcd6c8bb3e1736f23e51dce0c21659e0" },
    ]
    # The build's Node.js and the image's: upstream's major (AGENTS.md,
    # Updates).
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "24.22.3-trixie-slim", digest = "sha256:0a085df29353bca2c119e8fa2171773a4c7eab2a13330ee88b5e91ee4b21de9e" },
    ]
    # Upstream's major (its Dockerfile's corepack prepare).
    pnpm = [
      # renovate: datasource=npm depName=pnpm depType=automerge
      { version = "12.16.1" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    NODE_IMAGE    = "docker.io/library/node:${node.tag}@${node.digest}"
    # The tag's version, before its first "-".
    NODE_VERSION = split("-", node.tag)[0]
    PNPM_VERSION = pnpm.version
  }
  tags = tags("configarr", [base.version])
}
