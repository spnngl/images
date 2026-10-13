# kustomize

kustomize (Kubernetes manifest customization CLI, Go) built from
`kubernetes-sigs/kustomize` as tagged, no patch, with Helm (`helm/helm`,
as tagged) for its `helmCharts` generator: two static binaries on
`scratch`, like `containers/minio`: same user and layout. Runtime
contract: the Containerfile's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **helm is the only program kustomize execs here**, found in `/usr/bin`
  through the image's `PATH`. Another one (git, a KRM function runtime,
  kubectl) means leaving scratch: record that decision in REFERENCES.md
  first.
- **`/tmp` stays root's, mode 1777:** `build --enable-helm` writes there,
  as any UID.
- **Done when** the build passes: its smoke test (the Containerfile's)
  makes a kustomization from `smoke-test/` with `create` and `edit`,
  renders it offline with `--enable-helm`, and matches
  `smoke-test/expected.yaml` byte for byte.

## Updates

Renovate follows kustomize's `kustomize/v*` tags and Helm's `v*` tags;
minor and patch releases are automerged once CI passes, majors by hand.
Renovate fills in the checksum, the tag's peeled commit (tags are
annotated). A Helm update rebuilds the same image tag. Release notes:
<https://github.com/kubernetes-sigs/kustomize/releases>,
<https://github.com/helm/helm/releases>.

- **A release changes the rendered output** (`cmp` fails): run the smoke
  test's commands with upstream's released binaries, save the build's
  output as `smoke-test/expected.yaml`, and find the change in the
  release notes.
- **A release needs a newer Go** than the golang image (`go.work` for
  kustomize, `go.mod` for Helm; `GOTOOLCHAIN=local`): the build fails;
  move the `FROM` line to that Go.
- **A Helm major release:** merge it once kustomize's `checkHelmVersion`
  (`api/internal/builtins/HelmChartInflationGenerator.go`) accepts that
  major.
