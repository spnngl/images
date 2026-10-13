# nzbget: what to build and with which versions (containers/AGENTS.md).
# Dalec spec: no containerfile_args, Dalec fails on an undeclared one.
# par2 and rapidyenc: the tags NZBGet's cmake/*.cmake names (the spec checks
# it), in one Renovate PR with NZBGet (renovate.json5). Their tags carry a
# date after the release (v1.4.0-20260803): the regex versioning reads it as
# a build number, not a prerelease Renovate would skip.
target "nzbget" {
  name       = "nzbget-debian${debian}"
  context    = "containers/nzbget"
  dockerfile = "spec.yml"
  target     = "${DEBIAN[debian].codename}/container"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=nzbgetcom/nzbget extractVersion=^v(?<version>.+)$
      { version = "26.3", checksum = "674787848dddabf9047b8fc1a75cf92fe6e41c55" },
    ]
    par2 = [
      # renovate: datasource=github-tags depName=nzbgetcom/par2cmdline-turbo versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)-(?<build>\d+)$ extractVersion=^v(?<version>.+)$
      { version = "1.5.0-20261005", checksum = "4aa390514d0236c00810f2a74f4435b6fff5df37" },
    ]
    rapidyenc = [
      # renovate: datasource=github-tags depName=nzbgetcom/rapidyenc versioning=regex:^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)-(?<build>\d+)$ extractVersion=^v(?<version>.+)$
      { version = "1.1.1-20261006", checksum = "979f3344c9d78d0b115b45ae7e3cd32ae3857b04" },
    ]
  }
  args = {
    BASE_VERSION       = base.version
    BASE_CHECKSUM      = base.checksum
    PAR2_VERSION       = par2.version
    PAR2_CHECKSUM      = par2.checksum
    RAPIDYENC_VERSION  = rapidyenc.version
    RAPIDYENC_CHECKSUM = rapidyenc.checksum
  }
  tags = tags("nzbget", debian, [base.version])
}
