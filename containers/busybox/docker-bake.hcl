# busybox: what to build and with which versions (containers/AGENTS.md).
# The version is the mirror's tag (1_38_0), what Renovate's regex
# versioning reads; the build and the image tag get it dotted.
# No debian matrix: a static musl binary uses no Debian file at run
# time; Debian 13 only builds it.
target "busybox" {
  name       = "busybox"
  context    = "containers/busybox"
  dockerfile = "Containerfile"
  matrix = {
    base = [
      # renovate: datasource=github-tags depName=vda-linux/busybox_mirror versioning=regex:^(?<major>\d+)_(?<minor>\d+)_(?<patch>\d+)$
      { version = "1_38_0", checksum = "fc71374dfccd46448c62947269a35f1420d7ee28" },
    ]
  }
  args = merge(apt_args("13"), {
    BASE_VERSION  = replace(base.version, "_", ".")
    BASE_CHECKSUM = base.checksum
  })
  tags = tags("busybox", [replace(base.version, "_", ".")])
}
