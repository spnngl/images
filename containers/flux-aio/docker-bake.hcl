# flux-aio: what to build and with which versions (containers/AGENTS.md).
# One Flux release: flux2's tag (base) and the tag of each controller its
# manifests/bases/ names, which the build checks (lockstep). One Renovate
# PR for all eight (renovate.json5), merged by hand: AGENTS.md, Updates.
# The golang image of the Go minor release the controllers' Dockerfiles
# build with (ARG GO_VERSION), which the build checks too: tag and digest
# here, so Renovate follows that minor release only. Its own depName, not
# kubectl's: merged by hand (AGENTS.md, Updates).
target "flux-aio" {
  name       = "flux-aio-debian${debian}"
  context    = "containers/flux-aio"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    golang = [
      # renovate: datasource=docker depName=flux-aio-golang packageName=docker.io/library/golang extractVersion=^(?<version>1\.27\.\d+-trixie)$
      { tag = "1.27.3-trixie", digest = "sha256:c65ecfe613b539ac74c62a4c3b2c27e8f8a6076384c8f27e8a3c0f3be17cc385" },
    ]
    base = [
      # renovate: datasource=github-tags depName=fluxcd/flux2 extractVersion=^v(?<version>.+)$
      { version = "2.10.0", checksum = "3fa784edd773d56630bb9f62645e08f70c2cff0a" },
    ]
    source_controller = [
      # renovate: datasource=github-tags depName=fluxcd/source-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.1", checksum = "1e5c7c19b869b78b9a46cda940fa49bfc49c8ddb" },
    ]
    kustomize_controller = [
      # renovate: datasource=github-tags depName=fluxcd/kustomize-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.1", checksum = "746d9d2d360bbc7a5ee75ab79dadcf05e48ab927" },
    ]
    helm_controller = [
      # renovate: datasource=github-tags depName=fluxcd/helm-controller extractVersion=^v(?<version>.+)$
      { version = "1.7.1", checksum = "da037f220ee3e97eb91a70506b5c5f169e46bb68" },
    ]
    notification_controller = [
      # renovate: datasource=github-tags depName=fluxcd/notification-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.0", checksum = "08d8de010a16def89c1195b9360ceb1bd0042f70" },
    ]
    source_watcher = [
      # renovate: datasource=github-tags depName=fluxcd/source-watcher extractVersion=^v(?<version>.+)$
      { version = "2.3.1", checksum = "5ca0050aeadb8c77e4f9ad3421796024569f2bcc" },
    ]
    image_reflector_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-reflector-controller extractVersion=^v(?<version>.+)$
      { version = "1.3.0", checksum = "014ee11daea9b43e22f493b746f25d0f77643401" },
    ]
    image_automation_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-automation-controller extractVersion=^v(?<version>.+)$
      { version = "1.3.0", checksum = "075af583a5d3f9010bc52c33d137e615011cc8f3" },
    ]
  }
  args = merge(containerfile_args(debian), {
    GOLANG_TAG                           = golang.tag
    GOLANG_DIGEST                        = golang.digest
    BASE_VERSION                         = base.version
    BASE_CHECKSUM                        = base.checksum
    SOURCE_CONTROLLER_VERSION            = source_controller.version
    SOURCE_CONTROLLER_CHECKSUM           = source_controller.checksum
    KUSTOMIZE_CONTROLLER_VERSION         = kustomize_controller.version
    KUSTOMIZE_CONTROLLER_CHECKSUM        = kustomize_controller.checksum
    HELM_CONTROLLER_VERSION              = helm_controller.version
    HELM_CONTROLLER_CHECKSUM             = helm_controller.checksum
    NOTIFICATION_CONTROLLER_VERSION      = notification_controller.version
    NOTIFICATION_CONTROLLER_CHECKSUM     = notification_controller.checksum
    SOURCE_WATCHER_VERSION               = source_watcher.version
    SOURCE_WATCHER_CHECKSUM              = source_watcher.checksum
    IMAGE_REFLECTOR_CONTROLLER_VERSION   = image_reflector_controller.version
    IMAGE_REFLECTOR_CONTROLLER_CHECKSUM  = image_reflector_controller.checksum
    IMAGE_AUTOMATION_CONTROLLER_VERSION  = image_automation_controller.version
    IMAGE_AUTOMATION_CONTROLLER_CHECKSUM = image_automation_controller.checksum
  })
  tags = tags("flux-aio", [base.version])
}
