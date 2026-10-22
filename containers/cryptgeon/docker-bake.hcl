# Cryptgeon: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/cupcakearmy/cryptgeon/tags (stable only:
# extractVersion skips the -rc tags).
target "cryptgeon" {
  name       = "cryptgeon-debian${debian}"
  context    = "containers/cryptgeon"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=cupcakearmy/cryptgeon extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.9.3", checksum = "40f35595337a6008afd41cd834b8eb4e8644f956" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("cryptgeon", [base.version])
}
