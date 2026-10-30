# redis: what to build and with which versions (containers/AGENTS.md).
# One image per release line, tagged with its version and its line
# (redis:8.10.2, redis:8.10). Adding or dropping a line is an entry of
# this list: containers/redis/AGENTS.md (Updates).
target "redis" {
  name       = "redis-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/redis"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=redis-6.2 packageName=redis/redis versioning=semver extractVersion=^(?<version>6\.2\.\d+)$ depType=automerge
      { version = "6.2.24", checksum = "bfb69472301cb656043d3cbba332b406ef1d885a" },
      # renovate: datasource=github-tags depName=redis-7.2 packageName=redis/redis versioning=semver extractVersion=^(?<version>7\.2\.\d+)$ depType=automerge
      { version = "7.2.17", checksum = "83937c51afb53e1c69661c8e1533e0e19b896fe1" },
      # renovate: datasource=github-tags depName=redis-8.2 packageName=redis/redis versioning=semver extractVersion=^(?<version>8\.2\.\d+)$ depType=automerge
      { version = "8.2.10", checksum = "86b20b1b9e5f03d86db72c3d59bec432e471fbc9" },
      # renovate: datasource=github-tags depName=redis-8.4 packageName=redis/redis versioning=semver extractVersion=^(?<version>8\.4\.\d+)$ depType=automerge
      { version = "8.4.8", checksum = "03fb1dc35de324f2b062bfa46ab58b95af779809" },
      # renovate: datasource=github-tags depName=redis-8.6 packageName=redis/redis versioning=semver extractVersion=^(?<version>8\.6\.\d+)$ depType=automerge
      { version = "8.6.7", checksum = "3b450c3dcb075e59f50dbc0377151e25c8f375d4" },
      # renovate: datasource=github-tags depName=redis-8.8 packageName=redis/redis versioning=semver extractVersion=^(?<version>8\.8\.\d+)$ depType=automerge
      { version = "8.8.3", checksum = "76ec1c311045cf2f28332a95631259cc67ad4b51" },
      # renovate: datasource=github-tags depName=redis-8.10 packageName=redis/redis versioning=semver extractVersion=^(?<version>8\.10\.\d+)$ depType=automerge
      { version = "8.10.2", checksum = "498ecd0d6d007db11ddb3aea9428552598a78622" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    # SPDX, from each line's LICENSE.txt (COPYING up to 7.2): BSD up to
    # 7.2, RSALv2 or SSPLv1 from 7.4 (not built), AGPLv3 added from 8.0.
    LICENSES = (
      contains(["6.2", "7.2"], line(base.version)) ? "BSD-3-Clause" :
      "AGPL-3.0-only OR LicenseRef-RSALv2 OR SSPL-1.0"
    )
  })
  tags = tags("redis", [base.version, line(base.version)])
}
