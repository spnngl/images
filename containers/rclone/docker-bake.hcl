# rclone: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
# Releases: https://github.com/rclone/rclone/releases
target "rclone" {
  name       = "rclone-debian${debian}"
  context    = "containers/rclone"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=rclone/rclone extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "1.75.2", checksum = "be8d6044eacb843b74d335db0c5fbe09222031fe" },
    ]
  }
  args = {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
  }
  tags = tags("rclone", [base.version])
}
