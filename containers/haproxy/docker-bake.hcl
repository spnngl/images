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
      { version = "2.8.31", checksum = "5260599cc7f0ae2a058200cdfab2feda1403c48a" },
      # renovate: datasource=git-tags depName=haproxy-3.0 packageName=https://git.haproxy.org/git/haproxy-3.0.git versioning=semver extractVersion=^v(?<version>3\.0\.\d+)$ depType=automerge
      { version = "3.0.30", checksum = "47d806bd287e4d3d6e9c1be490f0173076f3e8c2" },
      # renovate: datasource=git-tags depName=haproxy-3.2 packageName=https://git.haproxy.org/git/haproxy-3.2.git versioning=semver extractVersion=^v(?<version>3\.2\.\d+)$ depType=automerge
      { version = "3.2.25", checksum = "70469d33ba0edc5503e292518ddf3e5df7aa9605" },
      # renovate: datasource=git-tags depName=haproxy-3.4 packageName=https://git.haproxy.org/git/haproxy-3.4.git versioning=semver extractVersion=^v(?<version>3\.4\.\d+)$ depType=automerge
      { version = "3.4.7", checksum = "8872a2604595140544774c2a6309a41186fc0f44" },
    ]
    # MaxMind's GeoLite2 databases as P3TERX republishes them: one release,
    # three files, each with its sha256 (Renovate's digest of the file).
    # The release is deleted about 6 days later: containers/haproxy/AGENTS.md
    # (Updates).
    geolite2 = [{
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      asn = { version = "2026.10.13", checksum = "7d1cf6cd79a0f35b446570058efb7d05cb6db6dd10bbbc09c3699473f6860cba" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.10.13", checksum = "56c24f912058b14be41085b6822f8c2f994f962429b563c3b34bcc84220f3cb9" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.10.13", checksum = "635078e412c4443a2950c2e3f775ccdc400e0a1fea5ffd32e5489e5401a9e51d" },
    }]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION              = base.version
    BASE_CHECKSUM             = base.checksum
    GEOLITE2_ASN_VERSION      = geolite2.asn.version
    GEOLITE2_ASN_CHECKSUM     = geolite2.asn.checksum
    GEOLITE2_CITY_VERSION     = geolite2.city.version
    GEOLITE2_CITY_CHECKSUM    = geolite2.city.checksum
    GEOLITE2_COUNTRY_VERSION  = geolite2.country.version
    GEOLITE2_COUNTRY_CHECKSUM = geolite2.country.checksum
  })
  tags = tags("haproxy", debian, [base.version, line(base.version)])
}
