# fedora: Fedora bootc with k3s (kubeenv), tagged <Fedora release>-v<Kubernetes
# minor>k3s. Containerfile, build and update rules: bootc/AGENTS.md.

target "fedora" {
  name       = "fedora-${base}"
  inherits   = ["bootc"]
  matrix = {
    base = [
      # Fedora releases from endoflife.date, not from the image's tags
      # (renovate.json5): fedora-bootc tags the branched release and rawhide
      # with their number months before release.
      # renovate: datasource=docker depName=quay.io/fedora/fedora-bootc packageName=quay.io/fedora/fedora-bootc versioning=docker
      "45",
    ]
  }
  # Shared with almalinux: the folder of the image's own files is beside it
  # (bootc/fedora/Containerfile.dockerignore).
  context    = "bootc"
  dockerfile = "fedora/Containerfile"
  target     = "kubeenv"
  platforms  = ["linux/amd64", "linux/arm64"]
  args = {
    BASE_VERSION        = base
    INSTALL_K3S_VERSION = K3S
  }
  tags = tags("fedora", ["${base}-v${line(trimprefix(K3S, "v"))}k3s"])
}
