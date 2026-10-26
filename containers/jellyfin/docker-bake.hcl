# jellyfin: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
# Releases: https://github.com/jellyfin/jellyfin/releases, built for
# trixie in https://repo.jellyfin.org/debian (jellyfin-server
# <version>+deb13). Renovate reads amd64's index: both architectures are
# published together.
target "jellyfin" {
  name       = "jellyfin-debian${debian}"
  context    = "containers/jellyfin"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=deb depName=jellyfin-server registryUrl=https://repo.jellyfin.org/debian?suite=trixie&components=main&binaryArch=amd64 versioning=loose extractVersion=^(?<version>\d+\.\d+(?:\.\d+)?)\+deb13$
      { version = "12.4" },
    ]
  }
  args = {
    BASE_VERSION = base.version
  }
  tags = tags("jellyfin", [base.version])
}
