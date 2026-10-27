# transmission: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
target "transmission" {
  name       = "transmission-debian${debian}"
  context    = "containers/transmission"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=transmission/transmission depType=automerge
      { version = "4.1.4", checksum = "a6d907d9ea2313143af714d7830feb6c1b60b84c" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  }
  tags = tags("transmission", [base.version])
}
