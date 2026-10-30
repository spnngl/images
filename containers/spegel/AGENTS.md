# spegel

Spegel (peer-to-peer OCI registry mirror for Kubernetes nodes, Go)
built from source as tagged, no patch, one static binary on `scratch`.
A drop-in for upstream's `ghcr.io/spegel-org/spegel` in its Helm chart
(`image.repository`, `image.tag`): same path (`/spegel`), entrypoint
and user. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Keep the `os-release` stage, `PRETTY_NAME="Distroless"` alone: the
  smoke test mounts the file the image copies.
- Root, with no capability: no `USER` line.
- `ENTRYPOINT ["/spegel"]` and no `CMD`.
- The build stage compiles and tests as UID 65532, with
  `containers/minio`'s cache ids.
- Keep `--keep-git-dir` and a clean tree: `spegel version` prints the
  tag git gives the build.

## Tests

The build stage runs upstream's unit tests (`go test -p 1 ./...`; keep
it off `-race`, REFERENCES.md), then the smoke test the comment above
it describes. Neither
runs `registry` against a containerd, nor upstream's integration tests
(`test/integration`): they need containerd 2.2 or later, and a kind
cluster.

## Updates

Renovate follows upstream's tags. Minor and patch releases (0.x minor
ones included) and golang bumps are automerged on the tests. For a
major release, or a failed build, compare the release
(`https://github.com/spegel-org/spegel/compare/v<old>...v<new>`)
against what the image assumes:

- the build flags: `.goreleaser.yaml`
- the test command: `.github/workflows/go.yaml`
- the preflight condition: `pkg/preflight/preflight.go`
- the flags and mounts the header names: `main.go`,
  `charts/spegel/templates/daemonset.yaml`
- the minimum containerd: `Validate` in
  `pkg/oci/containerd/containerd.go`
