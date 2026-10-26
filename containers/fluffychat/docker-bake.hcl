# FluffyChat: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/krille-chan/fluffychat/tags (stable only:
# extractVersion skips any pre-release tag).
# flutter, vodozemac, native_imaging, livekit: the releases FluffyChat's
# build names (.fvmrc, pubspec.lock: the Containerfile checks it), in one
# Renovate PR with FluffyChat (renovate.json5). native_imaging is a release
# file, with its sha256 (Renovate's digest of the file); the build gets
# its version without the tag's v.
target "fluffychat" {
  name       = "fluffychat-debian${debian}"
  context    = "containers/fluffychat"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=krille-chan/fluffychat extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.11.3", checksum = "6fc4920db43182e89cfec57c88baaa5044cb10dd" },
    ]
    flutter = [
      # renovate: datasource=github-tags depName=flutter/flutter extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "3.47.8", checksum = "737ba8f885dc774b53b442759999a312c9461e4e" },
    ]
    vodozemac = [
      # renovate: datasource=github-tags depName=famedly/dart-vodozemac extractVersion=^(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "0.8.1", checksum = "494dbbc732f8c1dbf8e6c07a11e9ca57f399ff7e" },
    ]
    native_imaging = [
      # renovate: datasource=github-release-attachments depName=famedly/dart_native_imaging depType=automerge
      { version = "v1.0.0", checksum = "35a4786bf91c48fc500af724fc6191bd7ecc5a4dc67a7b5e8a1ab745dad4252c" },
    ]
    livekit = [
      # renovate: datasource=github-tags depName=livekit/client-sdk-flutter extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.13.1", checksum = "ffc0a879383c4a347542fbfefe122c74006d7b91" },
    ]
    wasm_pack = [
      # renovate: datasource=crate depName=wasm-pack versioning=semver depType=automerge
      { version = "0.15.0" },
    ]
    sws = [
      # renovate: datasource=github-tags depName=static-web-server/static-web-server extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.44.1", checksum = "c5cbe67e91da91ccad838163cf9a034bf221a447" },
    ]
  }
  args = merge(apt_args(debian), {
    BASE_VERSION            = base.version
    BASE_CHECKSUM           = base.checksum
    FLUTTER_VERSION         = flutter.version
    FLUTTER_CHECKSUM        = flutter.checksum
    VODOZEMAC_VERSION       = vodozemac.version
    VODOZEMAC_CHECKSUM      = vodozemac.checksum
    NATIVE_IMAGING_VERSION  = trimprefix(native_imaging.version, "v")
    NATIVE_IMAGING_CHECKSUM = native_imaging.checksum
    LIVEKIT_VERSION         = livekit.version
    LIVEKIT_CHECKSUM        = livekit.checksum
    WASM_PACK_VERSION       = wasm_pack.version
    SWS_VERSION             = sws.version
    SWS_CHECKSUM            = sws.checksum
  })
  tags = tags("fluffychat", [base.version])
}
