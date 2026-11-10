# almalinux: AlmaLinux bootc with k3s (kubeenv) and geo-blocking, tagged
# <AlmaLinux release>-v<Kubernetes minor>k3s. Containerfile, build and update
# rules: bootc/AGENTS.md.

target "almalinux" {
  name     = "almalinux-${base}"
  inherits = ["bootc"]
  matrix = {
    base = [
      # renovate: datasource=docker depName=quay.io/almalinuxorg/almalinux-bootc packageName=quay.io/almalinuxorg/almalinux-bootc versioning=docker
      "10",
      # AlmaLinux 9 (EOL 2032) is kept for x86-64-v2 hosts: never moved to 10
      # (renovate.json5). almalinux-bootc:10 has v3 and v2 images, but the
      # docker-ce repository only has v3 binaries; 9 gives v2 binaries
      # without issue.
      # renovate: datasource=docker depName=quay.io/almalinuxorg/almalinux-bootc packageName=quay.io/almalinuxorg/almalinux-bootc versioning=docker
      "9",
    ]
  }
  # Shared with fedora: almalinux reuses its files (fedora/sysroot/common/).
  context    = "bootc"
  dockerfile = "almalinux/Containerfile"
  target     = "kubeenv"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    BASE_VERSION        = base
    INSTALL_K3S_VERSION = K3S
  }
  tags = tags("almalinux", ["${base}-v${line(trimprefix(K3S, "v"))}k3s"])
}
