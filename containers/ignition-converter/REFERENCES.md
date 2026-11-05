# ignition-converter: references

## Sources

- Upstream: `github.com/spnngl/ignition-converter` at tag
  `v<BASE_VERSION>`: `Makefile` (release build, `dist`),
  `cmd/ignition-converter/main.go` (flags, `--version`, TLS, timeouts),
  `cmd/ignition-converter/webhook.go` (`/mutate`, `/healthz`),
  `cmd/ignition-converter/testdata/` (Cluster API's renderings),
  `deploy.yaml` (manifests), `README.md` (behavior)
- AdmissionReview: `k8s.io/api/admission/v1`

## Decisions

- **One static binary on `scratch`:** `CGO_ENABLED=0` (`Makefile`), and
  the webhook execs nothing.
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build.
- **Upstream's release build, version included:** the `Makefile`'s
  `-trimpath` and `-s -w -X main.version=<version>`, the version without
  its `v`, as `release.yml` passes it. No `.git`: the version needs none.
- **The `golang` image's Go**, newer than or equal to `go.mod`'s: the
  standard library's fixes. Its `GOTOOLCHAIN=local`: a `go.mod` asking
  for a newer Go fails the build instead of downloading a toolchain; the
  next `golang` bump fixes it.
- **Built and tested as UID 65532:** the webhook doesn't get root in the
  build, and the test runs it as the image does.
- **Server test, two real reviews and a stop:** the TLS setup (a key
  pair read from files), the conversion through `/mutate`, failing
  closed and the graceful shutdown are what a release or a `golang` bump
  can break. The certificate is throwaway, made by the `golang` image's
  `openssl` and trusted by `curl`, so TLS is verified, not skipped. The
  first review's Secret holds `kubeadm-join.json`, Cluster API's own
  output, so the test converts what production converts; the patch's
  `ignition.version` must be `3.0.0`. The second holds data that isn't
  JSON and must be denied: `failurePolicy: Fail` relies on denial to
  keep a broken config off a machine. SIGTERM must exit 0: a rollout
  must not cut reviews in flight. Without `jq` in the `golang` image,
  `sed` and `base64` read the response: installing `jq` would need the
  Debian snapshot for one test.
- **Automerged minor and patch releases:** upstream's CI (`make check`,
  unit tests over Cluster API's renderings) gates every merge, and its
  release checks `--convert` on each architecture (`release.yml`); the
  server test covers the image. `e2e.sh`, the Fedora CoreOS boot, is
  manual upstream: no release waits on it. Majors by hand: a renamed
  flag breaks `deploy.yaml`'s `args`.
- **The image holds the binary and `LICENSE`** (Apache-2.0, section 4:
  its text goes with the binary; upstream has no `NOTICE`). **No CA
  bundle:** the webhook makes no outbound connection; it never calls the
  Kubernetes API (`deploy.yaml`: `automountServiceAccountToken: false`).
- **Port 8443:** upstream's `--addr` default, above 1024: no capability.
- **No `CMD`:** `--cert-file` and `--key-file` are required with no
  default, and `deploy.yaml` passes them and `--addr` as `args`.
- **No volume, no `WORKDIR`:** it writes nothing; every path is a flag.
- **No `HEALTHCHECK`:** nothing in the image can run a check.
