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
      { tag = "24.22.2-trixie-slim", digest = "sha256:54f84b4cf8432b21aaffd5d3ce8d41e12cea0d10d33c09d2f3c9879d49d6b446" },
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
