# Garage: what to build and with which versions (containers/AGENTS.md).
# Releases: https://git.deuxfleurs.fr/Deuxfleurs/garage/tags
target "garage" {
  name       = "garage-debian${debian}"
  context    = "containers/garage"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=forgejo-tags depName=Deuxfleurs/garage registryUrl=https://git.deuxfleurs.fr extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.4.1", checksum = "268334bd2530fa99f8b06c7383b2e9f776691edd" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("garage", [base.version])
}
