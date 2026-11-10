# fedora-coreos, Kubernetes nodes, and its GPU image: one pair per Kubernetes
# line (minor release), tagged <Fedora major>-v<Kubernetes minor>. Layers,
# tags and update rules: bootc/fedora-coreos/AGENTS.md and REFERENCES.md.
#
# Adding or dropping a line is an entry of `KUBERNETES` below
# (AGENTS.md, "Kubernetes lines").

# Kubernetes patch release of each line: kubelet, kubeadm and kubectl. One
# Renovate dependency per line, which extractVersion keeps in it. A variable,
# not a local: a matrix reads only variables.
variable "KUBERNETES" {
  type = list(string)
  default = [
    # renovate: datasource=github-tags depName=kubernetes-1.36 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.36\.\d+)$
    "1.36.6",
    # renovate: datasource=github-tags depName=kubernetes-1.37 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.37\.\d+)$
    "1.37.2",
  ]
}

# Fedora CoreOS release, with the stable stream's tag form.
variable "BASE" {
  # renovate: datasource=docker depName=quay.io/fedora/fedora-coreos packageName=quay.io/fedora/fedora-coreos versioning=docker
  default = "44.20261023.3.1"
}

# NVIDIA's driver branch and Container Toolkit of the GPU image: Renovate
# proposes them, never automerged (REFERENCES.md, "GPU image").
# The kmod-nvidia-open-dkms RPM of NVIDIA's CUDA repository for Fedora 44
# (the rpm datasource gives <version>-<release>: the release is dropped).
# One branch only (renovate.json5): a new branch is chosen by hand.
variable "NVIDIA_DRIVER" {
  # renovate: datasource=rpm depName=nvidia-driver packageName=kmod-nvidia-open-dkms registryUrl=https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/repodata/ versioning=loose extractVersion=^(?<version>[^-]+)-
  default = "620.70.06"
}

# The nvidia-container-toolkit-base RPM of NVIDIA's stable repository.
variable "NVIDIA_CONTAINER_TOOLKIT" {
  # renovate: datasource=rpm depName=nvidia-container-toolkit packageName=nvidia-container-toolkit-base registryUrl=https://nvidia.github.io/libnvidia-container/stable/rpm/x86_64/repodata/ versioning=loose extractVersion=^(?<version>[^-]+)-
  default = "1.20.2"
}

# fedora-coreos-<line> and fedora-coreos-nvidia-<line>, e.g.
# fedora-coreos-1-36. The GPU image is amd64 alone, nodes with GPUs being
# x86_64. SOURCE_DATE_EPOCH is "0": a per-commit value would rebuild every
# layer (REFERENCES.md, "Layers").
target "fedora-coreos" {
  name     = "fedora-coreos${gpu ? "-nvidia" : ""}-${replace(line(kube), ".", "-")}"
  inherits = ["bootc"]
  matrix = {
    kube = KUBERNETES
    gpu  = [false, true]
  }
  context    = "bootc/fedora-coreos"
  dockerfile = "Containerfile"
  platforms  = gpu ? ["linux/amd64"] : ["linux/amd64", "linux/arm64"]
  args = merge(
    {
      BASE_VERSION       = BASE
      KUBERNETES_VERSION = kube
      SOURCE_DATE_EPOCH  = "0"
    },
    gpu ? {
      IMAGE_BASE                    = "nvidia"
      NVIDIA_VERSION                = NVIDIA_DRIVER
      NVIDIA_CONTAINER_TOOLKIT_VERSION = NVIDIA_CONTAINER_TOOLKIT
    } : {},
  )
  tags = tags("fedora-coreos${gpu ? "-nvidia" : ""}", ["${split(".", BASE)[0]}-v${line(kube)}"])
}

# The scans, goss checks and their verdict (the Containerfile's reports
# stage), of the image above, exported to reports/: summary.txt, and failed
# only when a rule, a vulnerability or a check failed. amd64: the nodes are
# x86_64. build-bootc.yml builds it with the image, sharing its stages.
target "fedora-coreos-reports" {
  name     = "fedora-coreos${gpu ? "-nvidia" : ""}-${replace(line(kube), ".", "-")}-reports"
  inherits = ["fedora-coreos${gpu ? "-nvidia" : ""}-${replace(line(kube), ".", "-")}"]
  matrix = {
    kube = KUBERNETES
    gpu  = [false, true]
  }
  target    = "reports"
  platforms = ["linux/amd64"]
  tags      = []
  output    = ["type=local,dest=reports"]
}

# The images the VM tests run on (bootc/fedora-coreos/AGENTS.md, "Build
# check"): the nodes' image of each line; the GPU image has the same tests
# but its own platform files.
group "vm-test" {
  targets = [for kube in KUBERNETES : "fedora-coreos-${replace(line(kube), ".", "-")}"]
}

# The images released as OpenStack disk images (build-bootc.yml, release
# job): both images of each line, the GPU image's disk being left out of its
# line's release when it fails.
group "disk-image" {
  targets = flatten([for kube in KUBERNETES : [
    "fedora-coreos-${replace(line(kube), ".", "-")}",
    "fedora-coreos-nvidia-${replace(line(kube), ".", "-")}",
  ]])
}
