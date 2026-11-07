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
      { version = "main", checksum = "a52941174808fd21fd55b009e1fe3a47f460f508" },
    ]
    # Builds the web app only.
    node = [
      # renovate: datasource=docker depName=docker.io/library/node
      { tag = "24.22.2-trixie-slim", digest = "sha256:0820eaa85e07d0490446dd01d14707e17e6108a36988cf374899cd057eb3812d" },
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
