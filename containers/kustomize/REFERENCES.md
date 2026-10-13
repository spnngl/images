# kustomize: references

## Sources

- Upstream: `github.com/kubernetes-sigs/kustomize` at tag
  `kustomize/v<BASE_VERSION>`:
  - release build: `releasing/create-release.sh`
    (`build_kustomize_binary`), `.github/workflows/release.yaml`; Go:
    `go.work`
  - version: `api/provenance/provenance.go`,
    `kustomize/commands/version/version.go`
  - upstream's image: `kustomize.Dockerfile`,
    `releasing/cloudbuild_kustomize_image.yaml`
  - programs it execs: helm in
    `api/internal/builtins/HelmChartInflationGenerator.go`
    (`runHelmCommand`, `establishTmpDir`, `checkHelmVersion`) and
    `kustomize/commands/build/flagenablehelm.go`; git in
    `api/internal/git/gitrunner.go`; KRM functions and plugins in
    `kyaml/fn/runtime/exec/exec.go`,
    `kyaml/fn/runtime/container/container.go`,
    `api/internal/plugins/execplugin/execplugin.go`; kubectl in
    `kustomize/commands/openapi/fetch/fetch.go`
  - HTTPS resources: `api/internal/loader/fileloader.go`
- Helm: `github.com/helm/helm` at tag `v<HELM_VERSION>`: `Makefile`
  (`LDFLAGS`, `$(BINDIR)/$(BINNAME)`), `.goreleaser.yaml`,
  `.github/workflows/release.yml` (`make build-cross`),
  `internal/version/version.go`, `pkg/cli/environment.go` (`HELM_*`)
- Docs: <https://kubectl.docs.kubernetes.io/references/kustomize/>

## Decisions

- **Scratch, not Dalec:** kustomize's own work (local and HTTPS
  resources, generators, transformers, `create`, `edit`) execs nothing,
  and Helm is static Go, built here too. Upstream's image adds git and
  openssh for remote git resources; those, exec and container KRM
  functions, and `openapi fetch` (kubectl) would need Dalec and a
  userland, so the image covers what runs without them.
- **Helm included:** `helmCharts` is kustomize's built-in generator
  (`--enable-helm`), and it execs helm. Helm's current major, which
  `checkHelmVersion` accepts. Built as upstream's release: the Makefile's
  `LDFLAGS` (`-w -s`, version, commit, tree state, empty metadata on a
  tag), `-trimpath`, `CGO_ENABLED=0`, through its binary target:
  `make build-cross` needs goreleaser, and `make build` runs `go mod
  tidy` on the source. `build-cross`'s `-extldflags "-static"` has no
  effect without cgo (no external linker). The `GIT_*` make variables
  say what a release reads from git: no `.git` is fetched.
- **kustomize's release command, copied:** upstream has no make target
  for it. Run from the repository's root, so in `go.work`'s workspace:
  the kustomize, api and kyaml modules of one tag, as released. Version
  `v<BASE_VERSION>`, the tag after `kustomize/`, as `create-release.sh`
  sets it. Its `gitCommit` `-X` names no variable: upstream's binaries
  print `gitCommit: unknown` too. `buildDate` from `SOURCE_DATE_EPOCH`
  (the repository's last commit in CI): reproducible.
- **Commits pinned** (`ADD --checksum`): a moved tag fails the build.
- **One image tag, kustomize's version:** Helm is the image's
  dependency, and its updates rebuild the same tag.
- **`PATH=/usr/bin`:** kustomize runs `helm` by name (`--helm-command`'s
  default) through `PATH`, which a scratch image leaves to the runtime;
  setting it makes the lookup the same everywhere.
- **`/tmp` root's, 1777:** the Helm generator writes Helm's config,
  cache and data homes and the merged values file in `os.MkdirTemp`'s
  folder. World-writable and sticky, as Debian's, so any UID can run the
  image. Copied from a parent folder: a `COPY` of the folder itself
  creates its target 0755.
- **`WORKDIR /src`:** the kustomization's mount point, kustomize's
  default path (`.`), and where `create` and `edit` write. Root's, so
  only a mounted kustomization is written to. Charts missing from
  `charts/` are pulled there.
- **Registry credentials through `HELM_REGISTRY_CONFIG`:** kustomize
  passes its environment to helm, adding only the `HELM_*_HOME`
  variables, which point to a fresh temporary folder: a login there
  never outlives the run.
- **Smoke test from fixtures** (`smoke-test/`, in the build context):
  offline, with a local chart, so no outside service fails a build. The
  expected output
  comes from upstream's released binaries: the test proves this build
  renders as theirs. Releases and golang bumps are automerged on it.
- **The image holds the binaries, Debian's CA bundle** (HTTPS
  resources, chart repositories, OCI registries) and both `LICENSE`s
  (Apache-2.0).
- **`ENTRYPOINT` only, no `CMD`:** as upstream's image; arguments are
  kustomize's.
