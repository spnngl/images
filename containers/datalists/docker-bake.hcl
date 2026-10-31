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
      asn = { version = "2026.10.31", checksum = "a085c526fdd3e7cab68acc80c8c6cb11dbd9b1904f879f5084a17fc954ef9fbf" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.10.31", checksum = "9e52c48135043b0610c10d464151b9d26f7a6d91053b9243f1da9b5b9f9d5563" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.10.31", checksum = "7ef3b24a63044aee370098795c0ed01cb53bb2aaee8407dfc6475c5b42394d87" },
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
