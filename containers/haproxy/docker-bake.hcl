# haproxy: what to build and with which versions (containers/AGENTS.md).
# One image per release line, tagged with its version and its line
# (haproxy:3.2.25, haproxy:3.2); lines in support:
# https://www.haproxy.org/download/. Adding or dropping a line is an
# entry of this list: containers/haproxy/AGENTS.md (Updates).
# checksum: the release tarball's sha256, from the line's releases.json
# (custom datasource `haproxy`, renovate.json5).
target "haproxy" {
  name       = "haproxy-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/haproxy"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=custom.haproxy depName=haproxy-2.8 registryUrl=https://www.haproxy.org/download/2.8/src/releases.json versioning=semver extractVersion=^(?<version>2\.8\.\d+)$ depType=automerge
      { version = "2.8.33", checksum = "bb968c3b241692c448672d4c90bddb1e759cdeaf0d4eab1178c734b162fd5f48" },
      # renovate: datasource=custom.haproxy depName=haproxy-3.0 registryUrl=https://www.haproxy.org/download/3.0/src/releases.json versioning=semver extractVersion=^(?<version>3\.0\.\d+)$ depType=automerge
      { version = "3.0.32", checksum = "e9e93866280b8c8ef115eefe519ea17b1d7a2d893cc80c159251009dba5fd2a1" },
      # renovate: datasource=custom.haproxy depName=haproxy-3.2 registryUrl=https://www.haproxy.org/download/3.2/src/releases.json versioning=semver extractVersion=^(?<version>3\.2\.\d+)$ depType=automerge
      { version = "3.2.27", checksum = "3363a337dcde55a871b0f63ac483a4476db647418b85dee069b35f39291ee177" },
      # renovate: datasource=custom.haproxy depName=haproxy-3.4 registryUrl=https://www.haproxy.org/download/3.4/src/releases.json versioning=semver extractVersion=^(?<version>3\.4\.\d+)$ depType=automerge
      { version = "3.4.8", checksum = "024bd521a6cbbe32b426853147e6bbd6a89b107c5a34144846193fee5b7c6ed1" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("haproxy", [base.version, line(base.version)])
}
