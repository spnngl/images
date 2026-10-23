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
      # renovate: datasource=docker depName=flux-aio-golang packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$
      { tag = "1.26.10-trixie", digest = "sha256:909771fef53e3dcb0950255f0c9a8b4728c3b841e61509c7b29b098de7ee02d4" },
    ]
    base = [
      # renovate: datasource=github-tags depName=fluxcd/flux2 extractVersion=^v(?<version>.+)$
      { version = "2.9.6", checksum = "b9c17924adb533d3617ec7de97a7b0f4acc07b39" },
    ]
    source_controller = [
      # renovate: datasource=github-tags depName=fluxcd/source-controller extractVersion=^v(?<version>.+)$
      { version = "1.9.6", checksum = "456fa323ef6a4b977f220cf2c60298bf193497ba" },
    ]
    kustomize_controller = [
      # renovate: datasource=github-tags depName=fluxcd/kustomize-controller extractVersion=^v(?<version>.+)$
      { version = "1.9.6", checksum = "060e0d8dbc257a11cf49b9e626b63284dc385870" },
    ]
    helm_controller = [
      # renovate: datasource=github-tags depName=fluxcd/helm-controller extractVersion=^v(?<version>.+)$
      { version = "1.6.5", checksum = "37dce43a9bc5c89f99a44f8a6ea11f05a84f86b8" },
    ]
    notification_controller = [
      # renovate: datasource=github-tags depName=fluxcd/notification-controller extractVersion=^v(?<version>.+)$
      { version = "1.9.4", checksum = "a1dff35982bf7faf937f38ca2d5219907a6016d3" },
    ]
    source_watcher = [
      # renovate: datasource=github-tags depName=fluxcd/source-watcher extractVersion=^v(?<version>.+)$
      { version = "2.2.4", checksum = "06cb1109bfa7834e8403e2b543d9838e1623f85a" },
    ]
    image_reflector_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-reflector-controller extractVersion=^v(?<version>.+)$
      { version = "1.2.5", checksum = "d245eae59b9ef4928f69c556c13cd1729753349c" },
    ]
    image_automation_controller = [
      # renovate: datasource=github-tags depName=fluxcd/image-automation-controller extractVersion=^v(?<version>.+)$
      { version = "1.2.5", checksum = "119f65d75d1d50ef05a70c24afa0844005330576" },
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
