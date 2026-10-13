# kubectl: references

## Sources

- Upstream: `github.com/kubernetes/kubernetes` at tag
  `v<BASE_VERSION>`:
  - release build: `build/root/Makefile` (`all` target),
    `hack/make-rules/build.sh`, `hack/lib/golang.sh`
    (`KUBE_STATIC_BINARIES`, `build_binaries`: flags and tags,
    `verify_go_version`: `GOTOOLCHAIN`), `hack/lib/init.sh` (`_output`)
  - version: `hack/lib/version.sh` (`get_version_vars`: the
    `KUBE_GIT_*` variables; `ldflags`: `gitVersion`, `gitCommit`,
    `gitTreeState`, `gitMajor`, `gitMinor`, `buildDate`)
  - Go: `.go-version`
  - upstream's image: `build/server-image/kubectl/Dockerfile`,
    `build/common.sh` (`KUBECTL_BASE_IMAGE`: go-runner)
  - caches: `staging/src/k8s.io/cli-runtime/pkg/genericclioptions/config_flags.go`
    (`KUBECACHEDIR`),
    `staging/src/k8s.io/client-go/discovery/cached/disk/cached_discovery.go`
- Releases and support: <https://kubernetes.io/releases/>; skew:
  <https://kubernetes.io/releases/version-skew-policy/#kubectl>
- Docs: <https://kubernetes.io/docs/reference/kubectl/>

## Decisions

- **`kubernetes/kubernetes`, not `kubernetes/kubectl`:** the latter is a
  read-only mirror of `staging/src/k8s.io/kubectl`, the library; the
  binary is `cmd/kubectl` of the main repository, built and released
  from there.
- **One image per minor release:** kubectl supports an API server one
  minor release older or newer than itself (skew policy), so a cluster
  picks the line of its own release. `extractVersion` keeps each
  dependency on its line: Renovate never moves a line to the next minor
  release. A new line is added by hand, in the PR of `KUBERNETES_MINOR`
  (`docker-bake.hcl`), a dependency only there to announce it (AGENTS.md,
  Updates).
- **The Go of the tag's `.go-version`:** upstream builds and tests each
  release with it, and moves it within a line. A Bake matrix entry can't
  change a `FROM` line, so the golang image's tag and digest are each
  line's build arguments (`FROM` with `ARG`s), tracked by Renovate within
  the Go minor release (`extractVersion`). No default, as every version:
  BuildKit's `InvalidDefaultArgInFrom` check is skipped. The build checks
  the Go minor release against `.go-version`, and its patch release is
  not older. The digest updates join the Saturday group, as the `FROM`
  lines' do (`renovate.json5`). The tag names trixie: a Debian move edits
  it, as it edits the other images' `FROM` lines.
- **Upstream's release build** (`make all WHAT=cmd/kubectl`): static
  (`CGO_ENABLED=0`, kubectl is in `KUBE_STATIC_BINARIES`), `-trimpath`,
  `-s -w`, tags `selinux,notest,grpcnotrace`, from `vendor/` with
  `GOPROXY=off`; each line's own flags, none copied here.
  `GOTOOLCHAIN=local` (the golang image's): `verify_go_version` neither
  downloads a toolchain nor runs gimme.
- **Version from `KUBE_GIT_*`, not git:** `version.sh` reads them before
  git, so no `.git` is fetched; they say what upstream's release reads
  from git (the tag, its commit, a clean tree), and `ADD --checksum`
  proves the commit. `buildDate` comes from `SOURCE_DATE_EPOCH` (the
  repository's last commit in CI), not the clock: reproducible.
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build.
- **Built and tested as UID 65532:** upstream's scripts don't get root;
  the source stays root's, `_output` (the build's only output,
  `init.sh`) is the build user's. `GOCACHE` is set, or `golang.sh` puts
  it in `_output`; containers/minio's cache id, the same user.
- **Smoke test without an API server:** `kubectl apply --dry-run=client`
  still asks a server for discovery and OpenAPI; a server would mean
  building and running etcd and kube-apiserver. `kubectl create
  --dry-run=client -o yaml` builds a manifest client-side, and the
  version test catches a lost ldflag. Patch releases and golang bumps
  are automerged on it.
- **The image holds the binary, Debian's CA bundle** (TLS to API
  servers and OIDC issuers whose CA is public; most kubeconfigs embed
  their own), `LICENSE`, and `LICENSES/`: the licenses of the vendored
  code built into the binary. Not upstream's base image (go-runner, on
  distroless): the binary is static and needs none of it.
- **No `HOME`, no cache folder:** one command per container, so a
  discovery or HTTP cache wouldn't outlive it; kubectl skips them when
  unwritable (logged at `-v=1`), so the root filesystem can be
  read-only. The kubeconfig comes from `KUBECONFIG`, or in a pod from its
  service account.
- **`ENTRYPOINT` only, no `CMD`:** as upstream's image; arguments are
  kubectl's.
