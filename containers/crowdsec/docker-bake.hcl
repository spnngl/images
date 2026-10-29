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
      { version = "1.8.2", checksum = "3d369d64eb3e9ba770ed39aedc83ffd3170aef4c" },
    ]
    # The hub branch cscli picks for the latest CrowdSec release
    # (cmd/crowdsec-cli/core/require/branch.go): master, at a commit.
    hub = [
      # renovate: datasource=git-refs depName=crowdsecurity/hub packageName=https://github.com/crowdsecurity/hub
      { version = "master", checksum = "739f691d411eb29ff556faeeb22e19593389ef37" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    HUB_CHECKSUM  = hub.checksum
  }
  tags = tags("crowdsec", [base.version])
}
