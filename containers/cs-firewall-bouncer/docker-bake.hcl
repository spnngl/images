# cs-firewall-bouncer: what to build and with which versions
# (containers/AGENTS.md).
# Releases: https://github.com/crowdsecurity/cs-firewall-bouncer/releases
target "cs-firewall-bouncer" {
  name       = "cs-firewall-bouncer-debian${debian}"
  context    = "containers/cs-firewall-bouncer"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=crowdsecurity/cs-firewall-bouncer extractVersion=^v(?<version>\d+\.\d+\.\d+)$
      { version = "0.0.38", checksum = "20bd97a219259190229261b601e9f722178ac40d" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("cs-firewall-bouncer", debian, [base.version])
}
