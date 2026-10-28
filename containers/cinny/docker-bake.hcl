# Cinny: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/cinnyapp/cinny/tags; the server's:
# https://github.com/static-web-server/static-web-server/tags (stable
# only: extractVersion skips any pre-release tag).
target "cinny" {
  name       = "cinny-debian${debian}"
  context    = "containers/cinny"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=cinnyapp/cinny extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "4.12.8", checksum = "1e6412ed5b639607a8c7485f7d0b447f073fa09c" },
    ]
    sws = [
      # renovate: datasource=github-tags depName=static-web-server/static-web-server extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.44.1", checksum = "c5cbe67e91da91ccad838163cf9a034bf221a447" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    SWS_VERSION   = sws.version
    SWS_CHECKSUM  = sws.checksum
  })
  tags = tags("cinny", [base.version])
}
