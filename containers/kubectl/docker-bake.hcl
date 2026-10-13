# kubectl: what to build and with which versions (containers/AGENTS.md).
# One image per Kubernetes minor release, tagged with its version and its
# line (kubectl:<BASE_VERSION>-debian13, kubectl:<major.minor>-debian13);
# lines in support: https://kubernetes.io/releases/. Each line builds with
# the Go of its .go-version: its own golang image, tag and digest, in its
# entry.
# Adding or dropping a line is an entry of this list:
# containers/kubectl/AGENTS.md (Updates).

# The newest Kubernetes minor release, unused by the build: each line's
# comment follows only its patch releases, so this one's Renovate PR
# (never automerged) announces a new line, added in that PR (AGENTS.md,
# Updates).
variable "KUBERNETES_MINOR" {
  # renovate: datasource=github-tags depName=kubernetes-minor packageName=kubernetes/kubernetes versioning=loose extractVersion=^v(?<version>\d+\.\d+)\.0$
  default = "1.37"
}

target "kubectl" {
  name       = "kubectl-${replace(line(base.version), ".", "-")}-debian${debian}"
  context    = "containers/kubectl"
  dockerfile = "Containerfile"
  matrix = {
    debian = ["13"]
    base = [
      {
        # renovate: datasource=github-tags depName=kubectl-1.35 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.35\.\d+)$ depType=automerge
        version = "1.35.9", checksum = "329000efd0b26bd78155e51e4df449130f0fca00"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.9-trixie", digest = "sha256:f06b7122f888680048afb247c4e5f49c0069eb6c4c1ccae0f3f4834527a8d22c" }
      },
      {
        # renovate: datasource=github-tags depName=kubectl-1.36 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.36\.\d+)$ depType=automerge
        version = "1.36.5", checksum = "ad950d1cc78b0183c476bd4d3f1934c104229727"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.9-trixie", digest = "sha256:f06b7122f888680048afb247c4e5f49c0069eb6c4c1ccae0f3f4834527a8d22c" }
      },
      {
        # renovate: datasource=github-tags depName=kubectl-1.37 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.37\.\d+)$ depType=automerge
        version = "1.37.1", checksum = "f78e722310e50bcaca9276be22276d9e91d91308"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.9-trixie", digest = "sha256:f06b7122f888680048afb247c4e5f49c0069eb6c4c1ccae0f3f4834527a8d22c" }
      },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    GOLANG_TAG    = base.golang.tag
    GOLANG_DIGEST = base.golang.digest
  })
  tags = tags("kubectl", debian, [base.version, line(base.version)])
}
