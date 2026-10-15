# cs-haproxy-spoa-bouncer: what to build and with which versions
# (containers/AGENTS.md).
# Releases: https://github.com/crowdsecurity/cs-haproxy-spoa-bouncer/releases
target "cs-haproxy-spoa-bouncer" {
  name       = "cs-haproxy-spoa-bouncer-debian${debian}"
  context    = "containers/cs-haproxy-spoa-bouncer"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=crowdsecurity/cs-haproxy-spoa-bouncer extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.4.0", checksum = "60de9e913d65816d24e37bf6f8d33435a2aeae6c" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("cs-haproxy-spoa-bouncer", debian, [base.version])
}
