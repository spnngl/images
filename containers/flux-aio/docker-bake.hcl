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
      { tag = "1.27.4-trixie", digest = "sha256:b54b2639de8c1bfe538ec5ffc45f29b1932235ac5f6d63c059853646677112d9" },
    ]
    base = [
      # renovate: datasource=github-tags depName=fluxcd/flux2 extractVersion=^v(?<version>.+)$
      { version = "2.10.1", checksum = "23dcfe98fe672acdf44ecd9c60cbac41b57f5de8" },
    ]
    source_controller = [
      # renovate: datasource=github-tags depName=fluxcd/source-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.2", checksum = "521c8db36295ff75d77c2fe1854bdf2c7c630877" },
    ]
    kustomize_controller = [
      # renovate: datasource=github-tags depName=fluxcd/kustomize-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.2", checksum = "8ecafb1ca79986ef313355411d17aa4a14342df6" },
    ]
    helm_controller = [
      # renovate: datasource=github-tags depName=fluxcd/helm-controller extractVersion=^v(?<version>.+)$
      { version = "1.7.2", checksum = "b719f853ed67a80ed7899760da36c9e67c0adb58" },
    ]
    notification_controller = [
      # renovate: datasource=github-tags depName=fluxcd/notification-controller extractVersion=^v(?<version>.+)$
      { version = "1.10.1", checksum = "841beb3902457dddc40caf8d99175f24445afb81" },
    ]
    source_watcher = [
      # renovate: datasource=github-tags depName=fluxcd/source-watcher extractVersion=^v(?<version>.+)$
      { version = "2.3.1", checksum = "5ca0050aeadb8c77e4f9ad3421796024569f2bcc" },
    ]
    image_reflector_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-reflector-controller extractVersion=^v(?<version>.+)$
      { version = "1.3.1", checksum = "3c35e4843ba9bf74416517809b7e8b59923e499f" },
    ]
    image_automation_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-automation-controller extractVersion=^v(?<version>.+)$
      { version = "1.3.1", checksum = "bf5d9b3a10c00a4fb6aa7518d3ef256f11320174" },
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
