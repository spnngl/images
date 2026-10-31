# Mjolnir: what to build and with which versions (containers/AGENTS.md).
# Releases: https://github.com/matrix-org/mjolnir/tags (stable only:
# extractVersion skips any pre-release tag).
#
# The native addons' binaries, which their install scripts download
# unchecked: pinned here instead, at the versions of upstream's
# yarn.lock, which the build checks. Renovate lists their new releases
# on its Dependency Dashboard (containers/mjolnir/AGENTS.md, Updates).
target "mjolnir" {
  name       = "mjolnir-debian${debian}"
  context    = "containers/mjolnir"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=matrix-org/mjolnir extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "2.0.2", checksum = "23f2fec90e09752a7d28f58c35f76cfbd5e8999a" },
    ]
    # @tensorflow/tfjs-node, and the libtensorflow its install script
    # fetches at that version (scripts/install.js, deps-constants.js):
    # TensorFlow's on amd64, a build of tfjs' on arm64. Google publishes
    # no checksum: these are the archives' sha256.
    tfjs_node = [{
      # renovate: datasource=npm depName=@tensorflow/tfjs-node
      version             = "4.21.0"
      libtensorflow_amd64 = { version = "2.9.1", checksum = "7f510d2546e3db5e10b1d119463689003d587842892ad3c95bca51cf82820173" }
      libtensorflow_arm64 = { version = "2.7", checksum = "9395d1ff39f5b6847f5121e679ff4e599dc7061a2a7f87ceac061c78e908e6e3" }
    }]
    # @matrix-org/matrix-sdk-crypto-nodejs: its GitHub release's addon of
    # each platform, with its sha256 (Renovate's digest of the file).
    matrix_sdk_crypto = [{
      # renovate: datasource=github-release-attachments depName=matrix-org/matrix-rust-sdk-crypto-nodejs
      amd64 = { version = "v0.4.0", checksum = "7078d4dd987128f79afd192c4f621f64adece37e43f2a8756f1d0a9f034de718" },
      # renovate: datasource=github-release-attachments depName=matrix-org/matrix-rust-sdk-crypto-nodejs
      arm64 = { version = "v0.4.0", checksum = "0dc1c58315580cd0cef39c2e1ec28e1e38856a3376f2597da1ae20388f24d0f4" },
    }]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION                     = base.version
    BASE_CHECKSUM                    = base.checksum
    TFJS_NODE_VERSION                = tfjs_node.version
    LIBTENSORFLOW_VERSION_AMD64      = tfjs_node.libtensorflow_amd64.version
    LIBTENSORFLOW_CHECKSUM_AMD64     = tfjs_node.libtensorflow_amd64.checksum
    LIBTENSORFLOW_VERSION_ARM64      = tfjs_node.libtensorflow_arm64.version
    LIBTENSORFLOW_CHECKSUM_ARM64     = tfjs_node.libtensorflow_arm64.checksum
    MATRIX_SDK_CRYPTO_VERSION        = trimprefix(matrix_sdk_crypto.amd64.version, "v")
    MATRIX_SDK_CRYPTO_CHECKSUM_AMD64 = matrix_sdk_crypto.amd64.checksum
    MATRIX_SDK_CRYPTO_VERSION_ARM64  = trimprefix(matrix_sdk_crypto.arm64.version, "v")
    MATRIX_SDK_CRYPTO_CHECKSUM_ARM64 = matrix_sdk_crypto.arm64.checksum
  })
  tags = tags("mjolnir", [base.version])
}
