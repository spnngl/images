# crowdsec: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
target "crowdsec" {
  name       = "crowdsec-debian${debian}"
  context    = "containers/crowdsec"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=crowdsecurity/crowdsec extractVersion=^v(?<version>\d+\.\d+\.\d+)$
      { version = "1.8.1", checksum = "909b5157986a2b2c2163300fdaef5ed01289f7d2" },
    ]
    # The hub branch cscli picks for the latest CrowdSec release
    # (cmd/crowdsec-cli/core/require/branch.go): master, at a commit.
    hub = [
      # renovate: datasource=git-refs depName=crowdsecurity/hub packageName=https://github.com/crowdsecurity/hub
      { version = "master", checksum = "85d1ee489a5feffd4d1e903e1843fa8e5ac04e90" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    HUB_CHECKSUM  = hub.checksum
  }
  tags = tags("crowdsec", debian, [base.version])
}
