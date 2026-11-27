# flux-toolbox

A shell toolbox for Flux: `flux` (with its `schema` plugin),
`flux-operator`, `flate`, `kustomize`, `kubectl`, `helm`, `sops` and `nu`
(nushell, with its plugins) on this repository's git image (git, `ssh`,
busybox). For CI jobs and Kubernetes jobs that render, validate, diff or
apply what Flux deploys, and scripts that bootstrap it. Runtime contract:
the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **Upstream's release binaries, not builds:** each archive is checked
  against its release's checksum file, which Bake pins. sops is built
  from its tag (Bake pins the commit) with `containers/kustomize`'s Go,
  its modules as tagged: its release binary keeps the Go it was released
  with, and so its fixed vulnerabilities. flate too: its release has a
  checksum file per archive, none for all platforms. kubectl and
  helm, which have no GitHub release binary, come from
  `containers/kubectl` and `containers/kustomize`; git, `ssh` and
  busybox from `containers/git`, the base.
- **Every program static:** the git image has no C library. The build
  stage runs on it, so a dynamic binary fails the smoke test. A new tool
  ships a static Linux build, or stays out.
- **Nushell's plugins: all but upstream's examples and test fixtures**
  (`example`, `custom_values`, `stress_internals`). Shipped, not
  registered: a plugin registry is user state, under `HOME`.
- **flux's plugins outside `HOME`:** in `/usr/libexec/flux/plugins`,
  which `FLUXCD_PLUGINS` names; `HOME` is `/tmp`, empty at runtime.
- **Done when** the build and its structure test pass: the build stage checks every archive,
  runs each program at its pinned version (helm: its major), generates
  manifests offline (flux, flux-operator, kubectl), validates manifests
  against a schema extracted from a CRD (flux-schema, through `flux`),
  renders a chart (helm), encrypts and decrypts a file (sops), builds a
  kustomization and compares it byte for byte, renders a Flux repository
  from its commit (flate: substitution, a local chart), and loads and uses each
  nushell plugin; the structure test runs each program at its image path.

## Updates

flux, flux-schema, flux-operator, flate, kustomize, sops and nushell
automerge minor and patch releases when the build passes, majors by
hand; Renovate rewrites the pinned checksum file's sha256 (sops, flate:
the tag's commit) with the version. A flate release whose `go.mod` needs
a newer Go fails the build (the golang image sets `GOTOOLCHAIN=local`)
until `containers/kustomize`'s `golang` has it. Go follows `containers/kustomize`'s `golang` `FROM`
line, the same tag and digest, which Renovate updates in both. A flux
update changes the tag; another tool's rebuilds the same tag. git,
kubectl and helm follow `containers/git`'s, `containers/kubectl`'s and
`containers/kustomize`'s releases (their `FROM` lines, not automerged);
a Helm major there fails the smoke test here until it checks the new
major. Release notes:
<https://github.com/fluxcd/flux2/releases>,
<https://github.com/fluxcd/flux-schema/releases>,
<https://github.com/controlplaneio-fluxcd/flux-operator/releases>,
<https://github.com/home-operations/flate/releases>,
<https://github.com/kubernetes-sigs/kustomize/releases>,
<https://github.com/getsops/sops/releases>,
<https://github.com/nushell/nushell/releases>.
