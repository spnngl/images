# gentoo: what to build (containers/AGENTS.md). No version: each build
# takes Gentoo's latest stage3 of the flavor (REFERENCES.md). The tag,
# rolling, names the flavor: an image using it pins its digest.
# No debian matrix: the image has no Debian file; Debian 13 only fetches
# the stage3.
target "gentoo" {
  name       = "gentoo-${item.tag}"
  context    = "containers/gentoo"
  dockerfile = "Containerfile"
  matrix = {
    # flavor: Gentoo's, as its autobuilds name it
    # (latest-stage3-<arch>-<flavor>.txt), published for amd64 and
    # arm64: build-apps.yml builds every target for both. tag: the
    # flavor, OpenRC's without its suffix (REFERENCES.md).
    item = [
      { flavor = "musl-hardened-openrc", tag = "musl-hardened" },
      { flavor = "musl-hardened-systemd", tag = "musl-hardened-systemd" },
    ]
  }
  args = merge(apt_args("13"), {
    FLAVOR = item.flavor
  })
  tags = tags("gentoo", [item.tag])
  # The stage3's file times as Gentoo built them: portage records them
  # (containers/AGENTS.md, "File times").
  output = ["type=image,rewrite-timestamp=false"]
}
