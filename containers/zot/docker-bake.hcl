# zot: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/project-zot/zot/tags (stable only:
# extractVersion skips any pre-release tag).
target "zot" {
  name       = "zot-debian${debian}"
  context    = "containers/zot"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=project-zot/zot extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.1.22", checksum = "6bbc7e56db2b7a64eee589324efe5813245e3a28" },
    ]
    # The web UI: the tag ZUI_VERSION names in the Makefile of zot's tag,
    # which the build checks. Its tags have no order (commit-<hash>):
    # Renovate only follows this one's commit (containers/zot/REFERENCES.md).
    zui = [
      # renovate: datasource=git-refs depName=project-zot/zui packageName=https://github.com/project-zot/zui versioning=git
      { version = "commit-8e8457d", checksum = "8e8457d78748c314188fb624bfb46d2ffc744f1a" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    ZUI_VERSION   = zui.version
    ZUI_CHECKSUM  = zui.checksum
  })
  tags = tags("zot", [base.version])
}
