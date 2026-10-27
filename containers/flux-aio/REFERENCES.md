# flux-aio: references

## Sources

Each at the tag the image pins (`docker-bake.hcl`); controller paths are
in its own repository, `github.com/fluxcd/<controller>`.

- **flux2** `github.com/fluxcd/flux2`: `manifests/bases/<controller>/kustomization.yaml`
  (the release's controllers and their tags); `cmd/flux/check.go:203`
  and `pkg/manifestgen/labels.go:22` (`flux check` selects
  `app.kubernetes.io/part-of=flux`).
- **Release build**: each controller's `Dockerfile`
  (`ARG GO_VERSION`, the Go minor release;
  `CGO_ENABLED=0 go build -trimpath -a`, no ldflags, an Alpine image;
  kustomize-controller's adds `git`, `openssh-client`, `gnupg` and
  `tini`).
- **Go 1.27 broke image-automation-controller 1.2**: its
  `internal/update` tests (`TestUpdateWithSetters`) passed with Go 1.26,
  failed with Go 1.27 (the `$imagepolicy` markers were never set), and
  passed with Go 1.27 and `GOEXPERIMENT=nojsonv2`: Go 1.27's
  `encoding/json` is v2 by default. 1.3.0, built upstream with Go 1.27,
  passes them with Go 1.27.
- **Listen flags**: `main.go` (source-watcher: `cmd/main.go`), the
  `metrics-addr`, `health-addr`, `events-addr` flags, and
  notification-controller's `receiverAddr`; `storage-addr` (`:9090`),
  `storage-path` (`/data`) and `storage-adv-addr` in
  `github.com/fluxcd/pkg` `artifact/config/flags.go`, bound by
  source-controller and source-watcher. image-reflector-controller's
  `storage-path` (`/data`) is its own (`main.go:115`), and
  `internal/storage/format.go:35` (`ReconcileFormat`) wipes that folder
  when the storage backend changes (`FluxStorage` feature gate,
  `internal/features/features.go`).
- **Advertised artifact host**: `storage-adv-addr`, else the bound
  address (`github.com/fluxcd/pkg` `artifact/config/options.go`), is
  the artifact URL's host; kustomize-controller and helm-controller
  choose `SOURCE_WATCHER_LOCALHOST` when the URL holds
  `//source-watcher`.
- **pprof**: each controller's metrics server adds
  `pprof.GetHandlers()` (source-controller `main.go:461`, the others
  alike).
- **Artifact URLs to loopback**: kustomize-controller
  `internal/controller/kustomization_controller.go:365`
  (`SOURCE_CONTROLLER_LOCALHOST`, `SOURCE_WATCHER_LOCALHOST`),
  helm-controller `internal/loader/artifact_url.go:61`, source-watcher
  `internal/controller/artifactgenerator_controller.go:714`
  (`SOURCE_CONTROLLER_LOCALHOST`).
- **Execs**: none in the controllers' own code. Kustomize runs `git` for
  a remote base (`sigs.k8s.io/kustomize/api`
  `internal/git/gitrunner.go:25`), allowed unless `--no-remote-bases`
  (kustomize-controller `main.go:126`,
  `internal/controller/kustomization_controller.go:850`). SOPS' OpenPGP
  runs `gpg` (`github.com/getsops/sops` `pgp/keysource.go:630`), which
  kustomize-controller turns on
  (`internal/sops/keyservice/server.go:247`), and importing a `.asc`
  key runs it too (`internal/decryptor/decryptor.go:288`).
- **`--help` exits 0**: `github.com/spf13/pflag` `flag.go:1189`.
- **`TUF_ROOT`**: `github.com/sigstore/cosign/v3` `pkg/cosign/tuf.go:70`
  (else `$HOME/.sigstore/root`), through source-controller
  `internal/oci/cosign/cosign.go:222`.
- **flux-aio** `github.com/stefanprodan/flux-aio`
  `modules/flux-aio/templates/`: the Pod (`deployment.cue`, `Recreate`),
  each controller's arguments (`--storage-adv-addr`, and
  `--no-remote-bases` in its restricted profile), ports, probes and
  mounts.
- **Docs** `github.com/fluxcd/website` `content/en/flux/`:
  `installation/configuration/` (`vertical-scaling.md`,
  `proxy-setting.md`, `sharding.md`), `security/best-practices.md`,
  `security/secrets-management.md`.

## Checked

In kind, the Pod of the header's contract, the cluster side
from `flux install --export`: `flux check` passes; a Git source, a
Kustomization decrypting an age-encrypted Secret, a HelmRelease, an
ArtifactGenerator's ExternalArtifact applied by kustomize-controller,
an image policy whose update automation pushes its commit, alerts
received by a generic provider. From another Pod, the node's
`127.0.0.1` ports refuse, the others answer.

## Decisions

- **One image, one container per controller**: one pull, digest, scan
  and PR, and per controller its restarts, probes, resources and logs,
  as flux-aio runs them. One container under a supervisor shares one
  restart and one probe across seven processes; one linked binary would
  be a fork of seven modules.
- **Every controller of `manifests/bases/`**: a Pod runs the ones it
  needs; the others cost only image size.
- **Lockstep with flux2**: the image is one Flux release, whose
  controllers are tested together upstream. Checking the set too turns a
  controller Flux adds into a failed build, not a missing binary.
- **One Renovate group** (`renovate.json5`): controllers are tagged
  before flux2; alone, each PR would fail lockstep. Merged by hand: a
  release changes CRDs, which the cluster gets from `install.yaml`.
  The `golang` image stays out: patch releases, on their own.
- **Upstream's Go minor release, checked**: a newer one changes
  behaviour the controllers' tests don't cover (Go 1.27, above), so the
  `golang` image is pinned in `docker-bake.hcl`, where Renovate follows
  one minor release (as kubectl's), and the build fails when a
  controller's `Dockerfile` names another.
- **No remote bases, no OpenPGP** (SOPS with age, cloud KMS or Vault):
  they run `git` and `gpg`, the execs that would keep
  kustomize-controller off `scratch`. Remote bases are also off in
  Flux's security best practices.
- **Upstream's build, without `-a`, stripped**: `-a` rebuilds every
  package, defeating the build cache, for the same `-trimpath` output.
  `-s -w` drops the symbol table and DWARF, a large share of seven big
  binaries; panics still name functions (pclntab) and scanners still
  read the modules (build info). The newest patch release of that Go:
  the standard library's fixes.
- **The git directory kept** (`--keep-git-dir`): `go build` then stamps
  each binary with its tag and commit, which scanners match against the
  controllers' own advisories, and the build checks.
- **Tests check the binaries**: the controllers' behaviour is their own
  CI's, and needs a Kubernetes API server, which the build lacks. Hence
  `golang` PRs merged by hand: nothing in the build runs a controller.
- **No `ENTRYPOINT`, no `CMD`**: seven programs, none the default; a
  container without its command fails at start, not as the wrong
  controller.
- **Every listen flag set, on its own port**: three binaries default to
  `:9090` and all seven to `:8080` and `:9440`, which collide on one
  network. flux-aio's ports for its five controllers; the image
  controllers' in the free 9694-9697.
- **Loopback for the ports only siblings call** (both artifact servers,
  the events receiver): under `hostNetwork`, `:<port>` serves on every
  node address, and artifacts (sources, manifests) are served without
  authentication. Siblings reach them through `*_LOCALHOST`, with the
  advertised hosts flux-aio uses. Probes use `/readyz` on the health
  port, not flux-aio's `/` on the storage port. Metrics stay on every
  address, as flux-aio's, for the scrapers; the contract names their
  pprof.
- **Vulnerabilities wait for Flux**: lockstep pins every controller to
  one release, and the ignore files are for false positives.
- **The image holds the binaries, Debian's CA bundle** (Kubernetes API,
  Git, Helm and OCI registries, notification providers) and each
  `LICENSE` (Apache-2.0, no `NOTICE`). `TUF_ROOT=/tmp/.sigstore`: the
  default is under `HOME`, `/` without a passwd entry, read-only.
- **`/data` and `/tmp` owned by 65532**: a new Docker volume takes their
  owner. image-reflector-controller's database needs a volume of its own:
  it fills the folder's root, and a backend change wipes the folder, a
  shared `/data` included.
