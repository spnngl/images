# kustomize: what to build and with which versions (containers/AGENTS.md).
# Tags name kustomize's version alone: a Helm update rebuilds the same tag.
# Tags: https://github.com/kubernetes-sigs/kustomize/tags (kustomize/v*;
# api/, kyaml/ and cmd/config/ are its libraries)
target "kustomize" {
  name       = "kustomize-debian${debian}"
  context    = "containers/kustomize"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      # renovate: datasource=github-tags depName=kubernetes-sigs/kustomize extractVersion=^kustomize/v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "5.8.3", checksum = "6e4452f7b136fb9a261afe60830867a875183a71" },
    ]
    helm = [
      # renovate: datasource=github-tags depName=helm/helm extractVersion=^v(?<version>\d+\.\d+\.\d+)$ depType=automerge
      { version = "4.3.1", checksum = "c0d08d0d6d9424d4a14febb5e8a3e51b0dd00dff" },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    HELM_VERSION  = helm.version
    HELM_CHECKSUM = helm.checksum
  })
  tags = tags("kustomize", [base.version])
}
