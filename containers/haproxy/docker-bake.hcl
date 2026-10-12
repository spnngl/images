# haproxy: what to build and with which versions (containers/AGENTS.md).
# One image per release line, each tagged with its version and its line
# (haproxy:3.2.25-debian13, haproxy:3.2-debian13): the lines in support
# are listed in https://www.haproxy.org/download/ (2.8 and 3.0 are LTS
# lines in their last years). Adding or dropping a line is a line of this
# list, the Containerfile adapts by version (see the case on
# BASE_VERSION).
# Each line has its own git repository: the tags are
# https://git.haproxy.org/git/haproxy-<line>.git, v<version>, annotated:
# the checksum is the commit (peeled: "git ls-remote <repository>
# refs/tags/v<version>^{}"). extractVersion keeps Renovate within its line.
target "haproxy" {
  name       = "haproxy-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/haproxy"
  dockerfile = "Containerfile"
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
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("haproxy", debian, [base.version, line(base.version)])
}
