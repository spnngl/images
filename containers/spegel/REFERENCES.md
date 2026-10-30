# spegel: references

## Sources

- Upstream: `github.com/spegel-org/spegel` at tag `v<BASE_VERSION>`:
  `.goreleaser.yaml` (release build), `.github/workflows/go.yaml`
  (tests), `Dockerfile` (upstream's image),
  `main.go` (subcommands, flags and variables), `pkg/preflight`,
  `charts/spegel` (how it runs: mounts, ports, probes)
- Version output: `github.com/kvick-org/pkg`, `version/` (`version.Load`)
- Docs: `https://spegel.dev/docs/`

## Decisions

- **Commit pinned** (`ADD --checksum`): a node's containerd pulls
  through Spegel, so the tag is trusted only at the commit reviewed.
- **Upstream's release build:** `CGO_ENABLED=0 go build -trimpath
  -ldflags '-s -w'`, as `.goreleaser.yaml`; its `go mod tidy` hook is
  left out, the tag's `go.mod` is tidy. `version.Load` reads the main
  module's version from the build info, which go build stamps from
  git's tag on a clean tree: hence `--keep-git-dir`, else `spegel
  version` prints `devel`. The `golang` image's Go, at or above
  `go.mod`'s `toolchain`. amd64 and arm64 only, the platforms of
  `build-apps.yml`; upstream also builds arm/v7.
- **Built and tested as UID 65532:** the build and the test need no
  root, and the source stays root's, trusted by git through a system
  `safe.directory` set while root.
- **Root at runtime, as upstream's:** containerd's socket (`0660`) and
  `/etc/containerd/certs.d` are root's, and Spegel reads its content
  store. As their owner, root needs no capability (no
  `CAP_DAC_OVERRIDE`), so it runs with `--cap-drop all`.
- **`scratch` with an `os-release`:** with `KUBERNETES_SERVICE_HOST`
  set, `preflight.Check` fails unless `/etc/os-release`'s `PRETTY_NAME`
  is `Distroless` (upstream's base, `gcr.io/distroless/static`); the
  commit that added it (`d613cfb`) gives no reason. Not distroless: its
  extras are unused by Spegel, and the repository's static images are
  on `scratch` (`containers/minio`). Not patched out: the image is the
  tag, no patch. That field alone: without `ID`, scanners don't take
  the image for a Debian one. Written inline in a stage of its own
  (`os-release`), so the smoke test checks the file the image ships.
- **Upstream's unit tests in the build:** they cover `registry`'s
  code (`pkg/registry`, `pkg/oci`, `pkg/routing`) on fakes, which the
  smoke test can't reach. `go test -p 1`, not upstream CI's `-race`:
  `pkg/routing/libp2p`'s tests give up to 31 local peers 5 s to
  settle, which `-race` and packages tested alongside made them miss on
  the 4-vCPU runners, on both platforms (PR #187). The race detector
  checks upstream's code, upstream's CI's job; the image ships a binary
  built without it. About 40 s.
- **Tests without containerd:** `registry` needs containerd 2.2 or
  later (`Validate`); Debian trixie has 1.7. Building containerd for
  the test would be a second pinned dependency, and its daemon may not
  run unprivileged in a build; upstream's integration tests need it, or
  kind. So the smoke test stops `registry` at its containerd dial, and
  runs the steps upstream's chart runs without it (`configuration` as
  an init container, `cleanup` and `cleanup-wait` as post-delete
  hooks).
- **Automerged minor and patch releases:** Renovate counts 0.x minor
  releases as minor. What the tests miss (`registry` on a real
  containerd, peers) reaches the nodes, whose readiness probes keep a
  failing pod out.
- **The image holds the binary, Debian's CA bundle** (the OCI client's
  TLS, `pkg/oci/client.go`: registries' token auth; the HTTP
  bootstrapper takes its own CA), the `os-release` and `LICENSE`
  (MIT).
- **`/spegel`, its entrypoint and no `CMD`:** upstream's, so the chart
  applies with only `image.*` changed; every subcommand needs flags of
  the deployment.
- **No `VOLUME`, no `HEALTHCHECK`:** every path is a host path the
  deployment picks, and nothing in the image can run a check.
