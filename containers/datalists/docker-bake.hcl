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
      asn = { version = "2026.11.04", checksum = "81a3ae0bc347a4980766dc1d5434a3a9a8404cd371e62ee3a632ff2d4fdc0e3a" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.11.04", checksum = "d6ff9368ab19a13b096fd6392f752aa6c0890f2c92752d09253fab9e50501e46" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.11.04", checksum = "2c366a33fbdb4b41f162e22f72b0b9b416b13d55740b086be12c136b4cfc8f25" },
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
