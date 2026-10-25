# silo-server: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
target "silo-server" {
  name       = "silo-server-debian${debian}"
  context    = "containers/silo-server"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    # Upstream has no release: main, at a commit (REFERENCES.md).
    base = [
      # renovate: datasource=git-refs depName=Silo-Server/silo-server packageName=https://github.com/Silo-Server/silo-server
      { version = "main", checksum = "6de6d5e5e285a9b423e95a1122cb39e5bb9ca93b" },
    ]
    # Builds the web app only.
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "24.22.1-trixie-slim", digest = "sha256:43b9ba1142b8dcf33fa8f922ca1be85714adc444e0586c7cf7726daaeabc1bea" },
    ]
  }
  args = {
    # The revision Silo displays (internal/buildinfo): 8 characters.
    BASE_VERSION  = substr(base.checksum, 0, 8)
    BASE_CHECKSUM = base.checksum
    NODE_IMAGE    = "docker.io/library/node:${node.tag}@${node.digest}"
  }
  tags = tags("silo-server", [substr(base.checksum, 0, 8)])
}
