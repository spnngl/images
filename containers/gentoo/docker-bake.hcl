# gentoo: what to build (containers/AGENTS.md). No version: each build
# takes Gentoo's latest stage3 of the flavor (REFERENCES.md). The tag is
# the flavor, rolling: an image using it pins its digest.
# No debian matrix: the image has no Debian file; Debian 13 only fetches
# the stage3.
target "gentoo" {
  name       = "gentoo-${flavor}"
  context    = "containers/gentoo"
  dockerfile = "Containerfile"
  matrix = {
    # Gentoo's stage3 flavors, as its autobuilds name them
    # (latest-stage3-<arch>-<flavor>.txt), each published for amd64 and
    # arm64: build-apps.yml builds every target for both.
    flavor = ["musl-hardened-systemd"]
  }
  args = merge(apt_args("13"), {
    FLAVOR = flavor
  })
  tags = tags("gentoo", [flavor])
  # The stage3's file times as Gentoo built them: portage records them
  # (containers/AGENTS.md, "File times").
  output = ["type=image,rewrite-timestamp=false"]
}
