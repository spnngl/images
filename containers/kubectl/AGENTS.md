# kubectl

kubectl (Kubernetes command-line client, Go) built from
`kubernetes/kubernetes` as tagged, no patch, one static binary on
`scratch`, like `containers/minio`: same user and layout. One image per
Kubernetes minor release (`docker-bake.hcl`), each built with the Go of
its tag's `.go-version`. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **Upstream's build, not a `go build` of our own:** `make all
  WHAT=cmd/kubectl`, so each line keeps its own flags and tags; the
  version from the `KUBE_GIT_*` variables, checked by the smoke test.
- **The golang image is in `docker-bake.hcl`**, tag and digest, one per
  line: the one exception to the FROM-digest rule of
  [containers/AGENTS.md](../AGENTS.md). Its Go must be the minor release
  of the tag's `.go-version`, at that patch release or a newer one: the
  build checks it.
- **The build stage runs as UID 65532**, writing only to `/src/_output`,
  with containers/minio's Go build cache id.
- **Done when** the build passes: its smoke test checks `kubectl version
  --client` (version, commit, clean tree, major and minor), a static
  binary, and a ConfigMap generated with `kubectl create --dry-run=client
  -o yaml`, byte for byte; the final image runs `kubectl version
  --client`. No API server: see REFERENCES.md.

## Updates

Renovate moves each line within its minor release (`extractVersion`);
patch releases are automerged once CI passes. The checksum is the tag's
peeled commit (tags are annotated): Renovate fills it in. Each line's
golang image stays on its comment's Go minor release. Release notes:
`CHANGELOG/CHANGELOG-<line>.md` in the repository.

- **A release moves `.go-version` to another Go minor release**, which
  upstream does on a supported line: its build fails on the Go check.
  In that line's entry, set the golang comment's `depName` and
  `extractVersion` to the new minor release, and its tag and digest
  (`docker buildx imagetools inspect
  docker.io/library/golang:<tag>`).
- **Renovate moves `KUBERNETES_MINOR`** (a new minor release): in that
  PR, add the line. Copy an entry with its two `# renovate:` comments
  (`depName`, `extractVersion` for that line), the checksum from
  `git ls-remote https://github.com/kubernetes/kubernetes
  refs/tags/v<version>^{}`, and the golang image of the tag's
  `.go-version`.
- **Drop a line** at its end of life (<https://kubernetes.io/releases/>):
  delete its entry; its tags stay in the registry.
