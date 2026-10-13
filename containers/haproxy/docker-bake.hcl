# haproxy: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
# One image per release line, tagged with its version and its line
# (haproxy:3.2.25, haproxy:3.2); lines in support:
# https://www.haproxy.org/download/. Adding or dropping a line is an
# entry of this list: containers/haproxy/AGENTS.md (Updates).
target "haproxy" {
  name       = "haproxy-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/haproxy"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=git-tags depName=haproxy-2.8 packageName=https://git.haproxy.org/git/haproxy-2.8.git versioning=semver extractVersion=^v(?<version>2\.8\.\d+)$ depType=automerge
      { version = "2.8.30", checksum = "70dae8f09d58bd05c28a761d9b47136895b679d3" },
      # renovate: datasource=git-tags depName=haproxy-3.0 packageName=https://git.haproxy.org/git/haproxy-3.0.git versioning=semver extractVersion=^v(?<version>3\.0\.\d+)$ depType=automerge
      { version = "3.0.29", checksum = "de0ed893e219d55f111d2f2a24147d87b7d0b082" },
      # renovate: datasource=git-tags depName=haproxy-3.2 packageName=https://git.haproxy.org/git/haproxy-3.2.git versioning=semver extractVersion=^v(?<version>3\.2\.\d+)$ depType=automerge
      { version = "3.2.25", checksum = "70469d33ba0edc5503e292518ddf3e5df7aa9605" },
      # renovate: datasource=git-tags depName=haproxy-3.4 packageName=https://git.haproxy.org/git/haproxy-3.4.git versioning=semver extractVersion=^v(?<version>3\.4\.\d+)$ depType=automerge
      { version = "3.4.6", checksum = "56332c50b5291cfbbfd440d958adc988fbf87e2f" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  }
  tags = tags("haproxy", debian, [base.version, line(base.version)])
}
