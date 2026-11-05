# ignition-converter

Mutating admission webhook that rewrites the Ignition spec 2.x user data
of Cluster API bootstrap Secrets to spec 3.0, so Fedora CoreOS machines
boot (Go). Built from source as tagged, no patch, one static binary on
`scratch`. Upstream publishes binaries, no image: this is the one its
`deploy.yaml` names. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- Code changes go upstream (`github.com/spnngl/ignition-converter`) and
  reach the image as a tag; so do changes to `deploy.yaml`, the
  manifests.
- `--version` prints `main.version`, set by the build's
  `-X main.version=${BASE_VERSION}`; the server test checks it, and
  upstream's `AGENTS.md` counts on that check.
- An entrypoint and no `CMD`.
- The build stage compiles and tests as UID 65532, with
  `containers/minio`'s Go cache ids.
- Probes: `GET /healthz` on 8443, HTTPS.

## Updates

Renovate follows upstream's tags. Minor and patch releases and golang
bumps are automerged on the server test (`/healthz` over TLS, a
bootstrap Secret converted and one denied through `/mutate`, a clean
stop on SIGTERM); a major release by hand:
read `https://github.com/spnngl/ignition-converter/compare/v<old>...v<new>`
for flags and `deploy.yaml` changes. Check the flags and `--version`
against `cmd/ignition-converter/main.go`. A checksum-only update means
upstream moved the tag.
