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
      asn = { version = "2026.11.16", checksum = "6ab0dcb6017b0e5f356d4ac1607427fc5d4da7a8465cb1233e8a9c04df1b4885" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.11.16", checksum = "b98e1c4b9a90ec466048915106bec02ee3d4f0e5f11f59f232e0f0265a942f56" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.11.16", checksum = "c3ea0f8763a72c081d4abaf3366270d46414c55f6e36321621c6b59d53f9b17c" },
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
