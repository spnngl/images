# Numa: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/razvandimescu/numa/tags
target "numa-dns" {
  name       = "numa-dns-debian${debian}"
  context    = "containers/numa-dns"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=razvandimescu/numa extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.25.0", checksum = "91389fe65dfd6e36937b4d96fa95de5ef0239120" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("numa-dns", [base.version])
}
