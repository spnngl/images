# What every bootc image uses, with line() of the root docker-bake.hcl. Build
# and update rules: bootc/AGENTS.md. Every version is written once, behind a
# `# renovate:` comment (.github/AGENTS.md, "Bake workflows").

# k3s release of the kubeenv images (fedora, almalinux): its tag, which sets
# Kubernetes' version, and the tags' `-v<Kubernetes minor>k3s`. A variable:
# a file's locals are its own, and fedora and almalinux share it.
variable "K3S" {
  # renovate: datasource=github-releases depName=k3s packageName=k3s-io/k3s
  default = "v1.37.2+k3s1"
}

# Appended to every tag by a test run of build-bootc.yml (its manual
# input `test`): it pushes and releases without moving the tags hosts
# follow. Empty otherwise.
variable "TAG_SUFFIX" {
  default = ""
}

# Pushed to ghcr.io alone, hosts pull there (bootc/REFERENCES.md, "Signing").
function "tags" {
  params = [name, versions]
  result = [for v in versions : "ghcr.io/spnngl/images/${name}:${v}${TAG_SUFFIX}"]
}

# What every bootc image is: the label links the ghcr.io package to this
# repository. SOURCE_DATE_EPOCH is for build-bootc.yml to set where the image
# doesn't (bootc/fedora-coreos/REFERENCES.md, "Layers").
target "bootc" {
  labels = {
    "org.opencontainers.image.source" = "https://github.com/spnngl/images"
  }
}
