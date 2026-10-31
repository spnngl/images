# kubectl: what to build and with which versions (containers/AGENTS.md).
# One image per Kubernetes minor release, tagged with its version and its
# line (kubectl:<BASE_VERSION>, kubectl:<major.minor>);
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
        version = "1.35.10", checksum = "ae6fece6fea92ecfcccd13af7d5f2ea8cb9b33fe"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.10-trixie", digest = "sha256:909771fef53e3dcb0950255f0c9a8b4728c3b841e61509c7b29b098de7ee02d4" }
      },
      {
        # renovate: datasource=github-tags depName=kubectl-1.36 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.36\.\d+)$ depType=automerge
        version = "1.36.6", checksum = "1b2171b110bb2a2542e1322035c6583ec86eb976"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.10-trixie", digest = "sha256:909771fef53e3dcb0950255f0c9a8b4728c3b841e61509c7b29b098de7ee02d4" }
      },
      {
        # renovate: datasource=github-tags depName=kubectl-1.37 packageName=kubernetes/kubernetes versioning=semver extractVersion=^v(?<version>1\.37\.\d+)$ depType=automerge
        version = "1.37.2", checksum = "c50e5395f1ae2d4a2c05f28fdcc38c0916cc1a32"
        # renovate: datasource=docker depName=golang-1.26 packageName=docker.io/library/golang extractVersion=^(?<version>1\.26\.\d+-trixie)$ depType=automerge
        golang = { tag = "1.26.10-trixie", digest = "sha256:909771fef53e3dcb0950255f0c9a8b4728c3b841e61509c7b29b098de7ee02d4" }
      },
    ]
  }
  args = merge(containerfile_args(debian), {
    BASE_VERSION  = base.version
    BASE_CHECKSUM = base.checksum
    GOLANG_TAG    = base.golang.tag
    GOLANG_DIGEST = base.golang.digest
  })
  tags = tags("kubectl", [base.version, line(base.version)])
}
