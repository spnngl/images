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
      { version = "main", checksum = "9d3f24ca443688504147fa6938d1641845fc4c3c" },
    ]
    # Builds the web app only.
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "26.13.0-trixie-slim", digest = "sha256:ed670413da17a3a71ef1bf95ae5fb78817a39442c32f6428719e06358aec9128" },
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
