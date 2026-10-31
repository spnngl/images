# trivy: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/aquasecurity/trivy/releases
target "trivy" {
  name       = "trivy-debian${debian}"
  context    = "containers/trivy"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=aquasecurity/trivy extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.76.1", checksum = "e713f67f7d54decdcd9b3132c9751833dcced698" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("trivy", [base.version])
}
