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
      { version = "2.8.32", checksum = "a2bfd7dcdaeb75aa55ff15d3b9f698c4469c76a5f4a8a43a1e70df4d07acc66b" },
      # renovate: datasource=custom.haproxy depName=haproxy-3.0 registryUrl=https://www.haproxy.org/download/3.0/src/releases.json versioning=semver extractVersion=^(?<version>3\.0\.\d+)$ depType=automerge
      { version = "3.0.31", checksum = "5c423b6db7e99b0e61dcb1e310648274b00976ef24049ebbbebf28b3c183083c" },
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
