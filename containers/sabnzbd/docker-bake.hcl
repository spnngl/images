# sabnzbd: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
target "sabnzbd" {
  name       = "sabnzbd-debian${debian}"
  context    = "containers/sabnzbd"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=sabnzbd/sabnzbd
      { version = "5.1.3", checksum = "a647f73426cb70ad60ae7964b96c2d5e939b4727" },
    ]
    par2 = [
      # renovate: datasource=github-tags depName=animetosho/par2cmdline-turbo extractVersion=^v(?<version>.+)$ depType=automerge
      { version = "1.5.0", checksum = "3e60f6fcfed52bf257e79c46deae616cb6135d59" },
    ]
    uv = [
      # renovate: datasource=docker depName=ghcr.io/astral-sh/uv
      { version = "0.13.6" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    PAR2_VERSION  = par2.version
    PAR2_CHECKSUM = par2.checksum
    UV_VERSION    = uv.version
  }
  tags = tags("sabnzbd", [base.version])
}
