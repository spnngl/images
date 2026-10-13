# flux-toolbox

A shell toolbox for Flux: `flux`, `flux-operator`, `kustomize`, `kubectl`
and `nu` (nushell, with its plugins) on this repository's git image
(git, `ssh`, busybox). For CI jobs and Kubernetes jobs that render, diff
or apply what Flux deploys. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **Upstream's release binaries, not builds:** each archive is checked
  against its release's checksum file, which Bake pins. kubectl, which
  has no GitHub release, comes from `containers/kubectl`; git, `ssh` and
  busybox from `containers/git`, the base.
- **Every program static:** the git image has no C library. The build
  stage runs on it, so a dynamic binary fails the smoke test. A new tool
  ships a static Linux build, or stays out.
- **Nushell's plugins: all but upstream's examples and test fixtures**
  (`example`, `custom_values`, `stress_internals`). Shipped, not
  registered: a plugin registry is user state, under `HOME`.
- **Done when** the build passes: the build stage checks every archive,
  runs each program at its pinned version, generates manifests offline
  (flux, flux-operator, kubectl), builds a kustomization and compares it
  byte for byte, and loads and uses each nushell plugin; the final stage
  runs each program at its image path.

## Updates

flux, flux-operator, kustomize and nushell automerge minor and patch
releases when the build passes, majors by hand; Renovate rewrites the
pinned checksum file's sha256 with the version. A flux update changes the
tag; another tool's rebuilds the same tag. git and kubectl follow
`containers/git`'s and `containers/kubectl`'s releases (their `FROM`
lines, not automerged). Release notes:
<https://github.com/fluxcd/flux2/releases>,
<https://github.com/controlplaneio-fluxcd/flux-operator/releases>,
<https://github.com/kubernetes-sigs/kustomize/releases>,
<https://github.com/nushell/nushell/releases>.
