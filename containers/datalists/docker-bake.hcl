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
      asn = { version = "2026.11.22", checksum = "f62180496c7219698faa9fe7b6c1aa3aba089800473818b71ad88c22e12b4a22" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      city = { version = "2026.11.22", checksum = "032702cf8de2c5ad36b2cdc73d71df62477ef484acb872e4c1a24d7b9ec89666" },
      # renovate: datasource=github-release-attachments depName=P3TERX/GeoLite.mmdb versioning=loose
      country = { version = "2026.11.22", checksum = "6e72827d6291f3a3b8e94679d707003f6eca43bb5aca88e88c4b50120b96abbc" },
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
