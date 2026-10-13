# flux-toolbox: references

## Sources

- flux: `github.com/fluxcd/flux2`, release `v<BASE_VERSION>`:
  `flux_<version>_checksums.txt`, `flux_<version>_linux_<arch>.tar.gz`,
  `LICENSE` (at the tag)
- flux-operator: `github.com/controlplaneio-fluxcd/flux-operator`,
  release `v<FLUX_OPERATOR_VERSION>`:
  `flux-operator_<version>_checksums.txt`,
  `flux-operator_<version>_linux_<arch>.tar.gz` (with `LICENSE`)
- kustomize: `github.com/kubernetes-sigs/kustomize`, release
  `kustomize/v<KUSTOMIZE_VERSION>`: `checksums.txt`,
  `kustomize_v<version>_linux_<arch>.tar.gz`, `LICENSE` (at the tag)
- nushell: `github.com/nushell/nushell`, release `<NUSHELL_VERSION>`:
  `SHA256SUMS`, `nu-<version>-<x86_64|aarch64>-unknown-linux-musl.tar.gz`
  (`nu`, its plugins, `LICENSE`)
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
  file. Building four projects from source would be four toolchains for
  the same binaries.
- **kubectl from `containers/kubectl`:** Kubernetes publishes it on
  `dl.k8s.io`, not as a GitHub release; the image is already a static
  build, with its vendored code's licenses.
- **kustomize from its release, not `containers/kustomize`:** that image
  is built from source with Helm; the toolbox needs kustomize only, and
  its release binary is static. `kubectl kustomize` embeds the
  kustomize its Kubernetes release vendors, often an older one, hence
  the standalone one.
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
- **UID 65532, `HOME` `/tmp`:** the git image's user; kubectl and
  nushell write their caches and configuration under `HOME`.
- **Automerge:** the smoke test runs each program at its version and
  does real, offline work with each.
- **Licenses:** flux `Apache-2.0`, flux-operator `AGPL-3.0-only`,
  kustomize `Apache-2.0`, nushell `MIT`, kubectl `Apache-2.0` (its
  vendored code's in `/usr/share/doc/kubectl/`), all in
  `/usr/share/doc/<name>/`; git `GPL-2.0-only`, OpenSSH `SSH-OpenSSH`
  and busybox `GPL-2.0-only` from the base.
