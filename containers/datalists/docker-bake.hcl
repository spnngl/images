# datalists: what to build and with which versions (containers/AGENTS.md).
# Tagged `latest` only: the lists have no one version (GeoLite2's is a
# date, Cloudflare's and ipverse's none). An image using it pins its
# digest, which Renovate moves.
# No debian matrix: the image has no Debian file; Debian only checks the
# lists.
target "datalists" {
  name       = "datalists"
  context    = "containers/datalists"
  dockerfile = "Containerfile"
  matrix = {
    # MaxMind's GeoLite2 databases as P3TERX republishes them: one release,
    # three files, each with its sha256 (Renovate's digest of the file).
    # The release is deleted about 6 days later: containers/datalists/AGENTS.md
    # (Updates).
    geolite2 = [{
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      asn = { version = "2026.10.25", checksum = "dedeebd7aff855488b0e7a1a2a98f482cc255741c72f21f42a096509a21bff15" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.10.25", checksum = "26279009098e63c1ac57a58e321e9a58e74444c4c3184e8768d3f0866118beaf" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.10.25", checksum = "4d3587f2f39e8d5dced147bfcaa2a13b1655938930ed020e25929e91e1303fc8" },
    }]
  }
  args = {
    GEOLITE2_ASN_VERSION      = geolite2.asn.version
    GEOLITE2_ASN_CHECKSUM     = geolite2.asn.checksum
    GEOLITE2_CITY_VERSION     = geolite2.city.version
    GEOLITE2_CITY_CHECKSUM    = geolite2.city.checksum
    GEOLITE2_COUNTRY_VERSION  = geolite2.country.version
    GEOLITE2_COUNTRY_CHECKSUM = geolite2.country.checksum
  }
  tags = tags("datalists", ["latest"])
}
