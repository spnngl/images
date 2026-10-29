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
      { version = "1.37.0", checksum = "2b1c8cefbf8ac2b43670472e68ce42150313fa2d" },
    ]
    # The build's Node.js and the image's: upstream's major (AGENTS.md,
    # Updates).
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "24.22.2-trixie-slim", digest = "sha256:54f84b4cf8432b21aaffd5d3ce8d41e12cea0d10d33c09d2f3c9879d49d6b446" },
    ]
    # Upstream's major (its Dockerfile's corepack prepare).
    pnpm = [
      # renovate: datasource=npm depName=pnpm depType=automerge
      { version = "12.15.0" },
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
