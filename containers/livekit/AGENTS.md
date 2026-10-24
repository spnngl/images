# livekit

LiveKit server (WebRTC SFU, Go) built from source as tagged, one static
binary on `scratch`. Close to upstream's `livekit/livekit`: same build,
same entrypoint, but not root, and a default `--config` path. Runtime
contract: the Containerfile's header. `config.yaml` is the example, used
by `compose.yml` and by the build's server test. Upstream sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- No `ENV` for a setting the server also reads as a flag or variable
  (`NODE_IP`, `UDP_PORT`, `REDIS_HOST`, `LIVEKIT_KEYS`...): they override
  the config file, so a default here would silently beat the operator's
  file.
- `LIVEKIT_CONFIG` wins over `--config`: keep `CMD ["--config", ...]`,
  no need to replace it. Arguments replace `CMD`: to add a flag
  (`--node-ip`), repeat `--config /etc/livekit/config.yaml`, or the
  server starts on defaults.
- The build stage compiles and tests as UID 65532 (only packages install
  as root): its cache ids end in `-65532`, shared with `containers/minio`.
- `go tool wire diff` stays before the build: the release build
  regenerates `pkg/service/wire_gen.go`, this one doesn't.
- The server test and `compose.yml` use `config.yaml`: a key the server
  drops in a release fails the build. Keep every key the example needs,
  and only those.
- A key file is an absolute path, mode `0440` or `0400`. `stop_grace_period`
  (compose) and `terminationGracePeriodSeconds` (Kubernetes) are the longest
  session worth keeping: SIGTERM drains without limit.
- Probe: `GET /` on 7880 (200 `OK`; 406 until the node's stats exist).

## Updates

Renovate follows the repository's releases (drafts are not releases).
Minor and patch releases and Go bumps are automerged on the build stage's
server test, which covers the HTTP stack, the keys and the room API, not
media: **by hand, before the first merge and after a media-related
release** (read `CHANGELOG.md`), run `compose.yml` and join a room from
two browsers. When the test fails: read `CHANGELOG.md` between the tags
(`https://github.com/livekit/livekit/compare/<old>...<new>`); check the
flags in `cmd/server/main.go`, the build in `Dockerfile` and
`.goreleaser.yaml` (a new `go generate` step; a `go.mod` newer than the
`golang` image fails on `GOTOOLCHAIN=local`: bump `golang` first) and the
keys in `config.yaml` against `pkg/config/config.go`. The server parses
configs strictly, so a removed key breaks only the configs that use it:
the example's are tested, the operators' are not. A checksum-only update
means upstream moved the tag.
