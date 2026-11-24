# fedora-coreos, Kubernetes nodes: kubeadm images, their GPU images and k3s
# images, one each per Kubernetes line (minor release), tagged
# <Fedora major>-v<Kubernetes minor> (k3s: <Fedora major>-v<minor>k3s).
# Layers, tags and update rules: bootc/fedora-coreos/AGENTS.md and
# REFERENCES.md.
#
# Adding or dropping a line is an entry of `KUBERNETES` and of
# `K3S_RELEASES` below (AGENTS.md, "Kubernetes lines").

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

# k3s release of each line, with the sha256 of each architecture's binary (the
# release's `k3s` and `k3s-arm64` assets): the Containerfile checks the
# download against it. One Renovate dependency per line and architecture,
# which versioning keeps in its line and orders a `+k3s<n>` rebuild by <n>;
# Renovate takes the digest of the asset the current one belongs to, and both
# architectures move in one pull request. A line is Kubernetes' (same minor
# as KUBERNETES' entry). A variable, not a local: a matrix reads only variables.
#
# Its Bake target: fedora-coreos-k3s-<major>-<minor>.
function "k3s_target" {
  params = [k3s]
  result = "fedora-coreos-k3s-${replace(line(trimprefix(k3s.amd64.version, "v")), ".", "-")}"
}

variable "K3S_RELEASES" {
  type = list(object({
    amd64 = object({ version = string, checksum = string })
    arm64 = object({ version = string, checksum = string })
  }))
  default = [
    {
      # renovate: datasource=github-release-attachments depName=k3s-1.36 packageName=k3s-io/k3s versioning=regex:^v(?<major>1)\.(?<minor>36)\.(?<patch>\d+)\+k3s(?<build>\d+)$
      amd64 = { version = "v1.36.6+k3s1", checksum = "66ceb8e67edfa547195135d74783bfadc2ecc04a91059e90ae5f70a3dbc98c15" },
      # renovate: datasource=github-release-attachments depName=k3s-1.36 packageName=k3s-io/k3s versioning=regex:^v(?<major>1)\.(?<minor>36)\.(?<patch>\d+)\+k3s(?<build>\d+)$
      arm64 = { version = "v1.36.6+k3s1", checksum = "49dcecdb4f64f5e92bdc52d204d407fb39729e492f09074488125ee58b6f2895" },
    },
    {
      # renovate: datasource=github-release-attachments depName=k3s-1.37 packageName=k3s-io/k3s versioning=regex:^v(?<major>1)\.(?<minor>37)\.(?<patch>\d+)\+k3s(?<build>\d+)$
      amd64 = { version = "v1.37.2+k3s1", checksum = "265b3ee6a3198ef14033c63ef46cbb32370d83795199fb6d1b01f21575eddbda" },
      # renovate: datasource=github-release-attachments depName=k3s-1.37 packageName=k3s-io/k3s versioning=regex:^v(?<major>1)\.(?<minor>37)\.(?<patch>\d+)\+k3s(?<build>\d+)$
      arm64 = { version = "v1.37.2+k3s1", checksum = "a779ccf1e5e2e33a62f5a29c2f1c0bbf99431e100579d4c10f0aa0742a6aa84b" },
    },
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

# fedora-coreos-k3s-<line>, e.g. fedora-coreos-k3s-1-37: the k3s flavor, of
# the same repository as fedora-coreos, tagged <Fedora major>-v<k3s minor>k3s.
# Both architectures, as the nodes' image.
target "fedora-coreos-k3s" {
  name     = k3s_target(k3s)
  inherits = ["bootc"]
  matrix = {
    k3s = K3S_RELEASES
  }
  context    = "bootc/fedora-coreos"
  dockerfile = "Containerfile"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    BASE_VERSION       = BASE
    IMAGE_BASE         = "k3s"
    K3S_VERSION        = k3s.amd64.version
    K3S_CHECKSUM_AMD64 = k3s.amd64.checksum
    K3S_CHECKSUM_ARM64 = k3s.arm64.checksum
    SOURCE_DATE_EPOCH  = "0"
  }
  tags = tags("fedora-coreos", ["${split(".", BASE)[0]}-v${line(trimprefix(k3s.amd64.version, "v"))}k3s"])
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

# The k3s flavor's, likewise.
target "fedora-coreos-k3s-reports" {
  name     = "${k3s_target(k3s)}-reports"
  inherits = [k3s_target(k3s)]
  matrix = {
    k3s = K3S_RELEASES
  }
  target    = "reports"
  platforms = ["linux/amd64"]
  tags      = []
  output    = ["type=local,dest=reports"]
}

# The images the VM tests run on (bootc/fedora-coreos/AGENTS.md, "Build
# check"): the nodes' images of each line, kubeadm and k3s; the GPU image has
# the same tests but its own platform files. A target outside this group is
# pushed without waiting for the tests (build-bootc.yml).
group "vm-test" {
  targets = flatten([
    [for kube in KUBERNETES : "fedora-coreos-${replace(line(kube), ".", "-")}"],
    [for k3s in K3S_RELEASES : k3s_target(k3s)],
  ])
}

# The images released as OpenStack disk images (build-bootc.yml, release
# job): both images of each kubeadm line, the GPU image's disk being left out
# of its line's release when it fails, and the k3s image of each line, a
# release of its own.
group "disk-image" {
  targets = flatten([
    [for kube in KUBERNETES : [
      "fedora-coreos-${replace(line(kube), ".", "-")}",
      "fedora-coreos-nvidia-${replace(line(kube), ".", "-")}",
    ]],
    [for k3s in K3S_RELEASES : k3s_target(k3s)],
  ])
}
