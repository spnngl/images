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
      { version = "4.1.3", checksum = "838877323facc4cc2b677fe817e203779c437bb1" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  }
  tags = tags("transmission", [base.version])
}
