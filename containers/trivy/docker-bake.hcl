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
      { version = "0.76.2", checksum = "3f6334d223b52188324af3b9923b4249cd206652" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("trivy", [base.version])
}
