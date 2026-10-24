# MatrixRTC Authorization Service: what to build and with which versions
# (containers/AGENTS.md).
# Releases: https://github.com/element-hq/lk-jwt-service/releases
target "lk-jwt-service" {
  name       = "lk-jwt-service-debian${debian}"
  context    = "containers/lk-jwt-service"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-releases depName=element-hq/lk-jwt-service extractVersion=^v(?<version>\d+\.\d+\.\d+)$
      { version = "0.9.0", checksum = "0e176b1eca44e67b11484d0bdf56999807bf2b8e" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("lk-jwt-service", [base.version])
}
