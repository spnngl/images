# haproxy: what to build and with which versions (containers/AGENTS.md).
# One image per release line, tagged with its version and its line
# (haproxy:3.2.25, haproxy:3.2); lines in support:
# https://www.haproxy.org/download/. Adding or dropping a line is an
# entry of this list: containers/haproxy/AGENTS.md (Updates).
target "haproxy" {
  name       = "haproxy-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/haproxy"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=git-tags depName=haproxy-2.8 packageName=https://git.haproxy.org/git/haproxy-2.8.git versioning=semver extractVersion=^v(?<version>2\.8\.\d+)$ depType=automerge
      { version = "2.8.32", checksum = "6b68c8145ebbdc9131eeecdedc94145190d0daff" },
      # renovate: datasource=git-tags depName=haproxy-3.0 packageName=https://git.haproxy.org/git/haproxy-3.0.git versioning=semver extractVersion=^v(?<version>3\.0\.\d+)$ depType=automerge
      { version = "3.0.31", checksum = "f286fee02c93a5658f0ab89eec181d0daadd8bb8" },
      # renovate: datasource=git-tags depName=haproxy-3.2 packageName=https://git.haproxy.org/git/haproxy-3.2.git versioning=semver extractVersion=^v(?<version>3\.2\.\d+)$ depType=automerge
      { version = "3.2.27", checksum = "24d5d8c0c9c1cbefc8f76fdfd99252f467dc423e" },
      # renovate: datasource=git-tags depName=haproxy-3.4 packageName=https://git.haproxy.org/git/haproxy-3.4.git versioning=semver extractVersion=^v(?<version>3\.4\.\d+)$ depType=automerge
      { version = "3.4.7", checksum = "8872a2604595140544774c2a6309a41186fc0f44" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("haproxy", [base.version, line(base.version)])
}
