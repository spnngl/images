# flux-toolbox: references

## Sources

- flux: `github.com/fluxcd/flux2`, release `v<BASE_VERSION>`:
  `flux_<version>_checksums.txt`, `flux_<version>_linux_<arch>.tar.gz`,
  `LICENSE` (at the tag); plugin discovery: `internal/plugin/discovery.go`
  (`PluginDir`, `FLUXCD_PLUGINS`, `Discover`), `cmd/flux/plugin.go`
  (`registerPlugins`)
- flux-schema: `github.com/fluxcd/flux-schema`, release
  `v<FLUX_SCHEMA_VERSION>`: `flux-schema_<version>_checksums.txt`,
  `flux-schema_<version>_linux_<arch>.tar.gz` (with `LICENSE`);
  `.goreleaser.yml` (`CGO_ENABLED=0`), `internal/validator/defaults.go`
  (`DefaultSchemaLocation`), `docs/custom-schema-catalog.md`
- flux-operator: `github.com/controlplaneio-fluxcd/flux-operator`,
  release `v<FLUX_OPERATOR_VERSION>`:
  `flux-operator_<version>_checksums.txt`,
  `flux-operator_<version>_linux_<arch>.tar.gz` (with `LICENSE`)
- flate: `github.com/home-operations/flate`, tag `v<FLATE_VERSION>`
  (commit `FLATE_CHECKSUM`), with its `LICENSE`; `.goreleaser.yaml`
  (`CGO_ENABLED=0`, `-trimpath`, `-X main.version`; `checksum.split`:
  one `.sha256` per archive), `cmd/flate/main.go` (`version`),
  `go.mod` (`go` directive); `README.md` (local GitRepository source,
  `--cache-dir`/`FLATE_CACHE_DIR`, in memory without)
- kustomize: `github.com/kubernetes-sigs/kustomize`, release
  `kustomize/v<KUSTOMIZE_VERSION>`: `checksums.txt`,
  `kustomize_v<version>_linux_<arch>.tar.gz`, `LICENSE` (at the tag)
- nushell: `github.com/nushell/nushell`, release `<NUSHELL_VERSION>`:
  `SHA256SUMS`, `nu-<version>-<x86_64|aarch64>-unknown-linux-musl.tar.gz`
  (`nu`, its plugins, `LICENSE`)
- sops: `github.com/getsops/sops`, tag `v<SOPS_VERSION>` (commit
  `SOPS_CHECKSUM`), with its `LICENSE`; `.goreleaser.yaml`
  (`binary-linux`: `CGO_ENABLED=0`, `-trimpath`, `-mod=readonly`,
  `-X .../version.Version`), `version/version.go` (`PrintVersion`),
  `go.mod` (`filippo.io/age`, whose `cmd/age-keygen` the smoke test
  builds); Go: `containers/kustomize`'s `golang` image
- helm: `containers/kustomize`'s image, `/usr/bin/helm` and
  `/usr/share/doc/helm/LICENSE` (`github.com/helm/helm` at
  `v<HELM_VERSION>`, built there)
- Renovate: `lib/modules/datasource/github-release-attachments/index.ts`
  (`getDigest`, `findDigestAsset`, `mapDigestAssetToRelease`)
- Docs: <https://fluxcd.io/flux/cmd/>,
  <https://fluxcd.control-plane.io/operator/cli/>,
  <https://www.nushell.sh/book/plugins.html>

## Decisions

- **A shell, against the rule of `containers/AGENTS.md`:** a toolbox is
  run interactively or by scripts; `/bin/sh` is the default command,
  the git image's entrypoint (`git`) reset.
- **`FROM` the git image:** Flux's sources are git repositories, and the
  git image is static git, `ssh`, a CA bundle and busybox (shell,
  coreutils, passwd with 65532). It is also the build stage: busybox has
  `sha256sum` and `tar`, and every binary is tested on the system it
  ships on, with no C library.
- **Release binaries, not built:** each is static (Go's; nushell's
  `*-unknown-linux-musl` build), checked against upstream's checksum
  file. Building five projects from source would be six toolchains for
  the same binaries.
- **sops built, not its release binary:** that binary ships the Go it
  was released with: a critical vulnerability of Go's standard library,
  fixed since, failed the image scan (GO-2026-6612, sops 3.13.3 built
  with Go 1.26.5) until sops' next release. Built from the tag as
  upstream's release is (`.goreleaser.yaml`), with its modules as
  tagged, as `containers/kustomize` builds kustomize and Helm, and on
  the same `golang` image (tag and digest), so that Renovate updates
  both at once. Renovate's `github-tags` datasource pins the tag's
  commit, `ADD --checksum` checks it.
- **flate built, not its release binary:** its release splits its
  checksums, one `.sha256` per archive (`checksum.split`), so there is
  no one file whose sha256 Bake could pin for every platform, and
  Renovate keeps one digest per dependency. Built from the tag as sops
  is, in the same stage: one commit pins every platform, and it gets the
  current Go. `go -C` builds each module from its own folder.
- **flate's smoke test, offline:** a GitRepository whose URL is the
  checkout's remote, with a branch ref, is read from the committed
  files (`README.md`, "What flate renders"); its Kustomization
  substitutes a variable and its HelmRelease renders a chart from that
  source. Nothing is fetched: `example.com` serves no repository.
- **kubectl from `containers/kubectl`:** Kubernetes publishes it on
  `dl.k8s.io`, not as a GitHub release; the image is already a static
  build, with its vendored code's licenses.
- **helm from `containers/kustomize`:** Helm publishes its binaries on
  `get.helm.sh`; its GitHub releases hold only signatures, so Renovate's
  `github-release-attachments` has no checksum file to pin. The
  kustomize image already builds Helm's current major from its tag,
  static, for its `helmCharts` generator; its `FROM` digest pins it.
  The smoke test checks the major (Helm 4), the version being that
  image's.
- **flux-schema in `/usr/libexec/flux/plugins`, named by
  `FLUXCD_PLUGINS`:** flux runs `flux-<name>` from that folder as `flux
  <name>`, else from `~/.fluxcd/plugins`, under `HOME`, which is `/tmp`,
  empty or a tmpfs at runtime. A folder of its own, not `/usr/bin`:
  flux would take `flux-operator` for a plugin (`flux operator`). flux
  needs the binary alone, not the receipt `flux plugin install` writes
  beside it. Root's: `flux plugin install` needs `FLUXCD_PLUGINS` set
  to a writable folder. `flux schema validate` reads schemas from
  flux-schema's catalog on GitHub by default (`DefaultSchemaLocation`),
  caching them in memory only: it writes nothing under `HOME`.
- **sops' smoke test key:** sops makes no age key, so the sops stage
  also builds `age-keygen`, from the age sops requires (no other
  version, no other download); the build stage makes a fresh pair with
  it. Neither ships: no key in the repository (its secret scan flags
  one, even a public test key), nor `age-keygen` in the image.
- **kustomize from its release, not `containers/kustomize`:** its
  release binary is static and checked like the others; only Helm, with
  no release binary to pin, comes from that image. `kubectl kustomize`
  embeds the kustomize its Kubernetes release vendors, often an older
  one, hence the standalone one.
- **Renovate: `github-release-attachments`, the checksum file's
  sha256:** the datasource looks a release up by its tag
  (`releases/tags/<tag>`), so Bake holds the full tag (`v<BASE_VERSION>`,
  `kustomize/v<KUSTOMIZE_VERSION>`) and the build strips the prefix. It finds the
  pinned digest among the release's assets (small files are read for
  checksum lines, others hashed) and, on update, hashes the asset whose
  name has the new version. Pinning the checksum file, not each archive,
  keeps one digest per tool for every platform; `ADD --checksum` checks
  it, `sha256sum -c` checks each archive against it. kustomize's
  `regex:` versioning skips its libraries' tags (`api/`, `kyaml/`,
  `cmd/config/`). `renovate.json5`'s three-day wait covers the
  datasource.
- **Licenses not pinned:** flux's and kustomize's archives have none;
  each comes from `raw.githubusercontent.com` at the tag, text only.
- **Nushell's plugins:** `formats`, `gstat`, `inc`, `polars`, `query`,
  upstream's own. `example`, `custom_values` and `stress_internals` are
  examples and test fixtures. Not registered: `plugin add` writes the
  registry under `HOME` (`/tmp`), state a runtime may not keep.
- **Tag: flux's version:** the image is Flux's toolbox; another tool's
  update rebuilds it.
- **UID 65532, `HOME` `/tmp`:** the git image's user; kubectl, helm and
  nushell write their caches and configuration under `HOME`. flate
  keeps its cache in memory unless given one (`--cache-dir`,
  `FLATE_CACHE_DIR`).
- **Automerge:** the smoke test runs each program at its version and
  does real, offline work with each.
- **Licenses:** flux `Apache-2.0`, flux-schema `Apache-2.0`,
  flux-operator `AGPL-3.0-only`, flate `AGPL-3.0-only` (its `LICENSE`,
  version 3, with no "or later" notice), kustomize `Apache-2.0`, helm
  `Apache-2.0`, sops `MPL-2.0`, nushell `MIT`, kubectl `Apache-2.0` (its
  vendored code's in `/usr/share/doc/kubectl/`), all in
  `/usr/share/doc/<name>/`; git `GPL-2.0-only`, OpenSSH `SSH-OpenSSH`
  and busybox `GPL-2.0-only` from the base.
