# ignition-converter: what to build and with which versions
# (containers/AGENTS.md).
# Tags: https://github.com/spnngl/ignition-converter/tags
target "ignition-converter" {
  name       = "ignition-converter-debian${debian}"
  context    = "containers/ignition-converter"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=spnngl/ignition-converter extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.1.2", checksum = "206ff707aa2436b726cf6a5ec6c8a6a712d5319a" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("ignition-converter", [base.version])
}
