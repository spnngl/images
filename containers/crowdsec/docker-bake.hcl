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
      { version = "master", checksum = "bdc19c25e42a2b9b75b7522cb2383ed01aea4570" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    HUB_CHECKSUM  = hub.checksum
  }
  tags = tags("crowdsec", [base.version])
}
