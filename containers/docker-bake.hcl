# What every containers/<name>/docker-bake.hcl uses. Build and update
# rules: containers/AGENTS.md.

# Debian releases images build on, by version; an image names its own
# (its matrix's `debian`). A map, so Debian 14 is added while images move
# one by one. Moving an image means editing its FROM lines too
# (containerfile_args' codename is checked).
variable "DEBIAN" {
  type    = map(object({ codename = string }))
  default = { "13" = { codename = "trixie" } }
}

# Debian's archive at one point in time, for every Containerfile that
# installs packages (containers/AGENTS.md). Archive-wide, the same for
# every Debian release.
variable "DEBIAN_SNAPSHOT" {
  # renovate: datasource=custom.debian-snapshot depName=debian-snapshot
  default = "20261012T203205Z"
}

# <major>.<minor> of a version: a release line.
function "line" {
  params = [version]
  result = regex("^[0-9]+\\.[0-9]+", version)
}

# Tags name the upstream version alone (haproxy:3.2.25): Debian only
# builds the image, and most images are scratch, with no Debian file.
function "tags" {
  params = [name, debian, versions]
  result = [for v in versions : "ghcr.io/spnngl/images/${name}:${v}"]
}

# Arguments of every Containerfile. Not for Dalec specs: Dalec fails on
# an argument the spec doesn't declare (load.go, errUnknownArg).
# DEBIAN_CODENAME: the build stage checks it runs on that release, so the
# target's debian matches its FROM lines (they name the release, not Bake).
function "containerfile_args" {
  params = [debian]
  result = {
    DEBIAN_CODENAME = DEBIAN[debian].codename
  }
}

# Containerfile_args and the snapshot, for a Containerfile that installs
# packages (an argument no instruction reads is a build warning).
function "apt_args" {
  params = [debian]
  result = merge(containerfile_args(debian), {
    DEBIAN_SNAPSHOT_VERSION = DEBIAN_SNAPSHOT
  })
}
