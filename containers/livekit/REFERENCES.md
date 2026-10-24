# livekit: references

## Sources

- Upstream: `github.com/livekit/livekit` at tag `v<BASE_VERSION>`:
  `Dockerfile` and `.goreleaser.yaml` (release build), `cmd/server/main.go`
  (flags, variables, signals, `getConfigString`), `pkg/config/config.go`
  (defaults, key file permissions), `pkg/service/server.go` (health,
  shutdown), `config-sample.yaml`, `magefile.go`, `.github/workflows/docker.yaml`
- Ports and node IP: `github.com/livekit/mediatransportutil`
  `pkg/rtcconfig/config.go` (at the version `go.mod` pins)
- Tokens: `github.com/livekit/protocol` `auth/` (claims, HS256, `exp`
  required)
- Wire: `github.com/google/wire` `cmd/wire/main.go` (`diff` exit codes)
- Docs: <https://docs.livekit.io/transport/self-hosting/>

## Decisions

- **`golang:<minor>-trixie`, `GOTOOLCHAIN=local`:** upstream's `Dockerfile`
  builds with the latest Go and `GOTOOLCHAIN=local`, so the image's Go
  is authoritative and newer than `go.mod`'s. The same image as
  `containers/minio`: Renovate moves both, the caches are shared.
- **Upstream's release build, `-trimpath` added:** `CGO_ENABLED=0 go
  build ./cmd/server`, no ldflags: `--version` comes from the constant in
  `version/version.go`, so the source needs no `.git`. Go embeds the
  module list in the binary: the SBOM and the scans see it without
  `cargo auditable`'s equivalent.
- **`wire diff` before the build:** goreleaser (`go generate ./...`) and
  `docker.yaml` (`mage generate`) regenerate `wire_gen.go`; this build
  uses the committed file, and fails if the tag's is stale. Read-only, so
  the source stays root's. counterfeiter's fakes are test code.
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build.
- **Built and tested as UID 65532:** the module's code and the test
  server run without root and can't change the source (root's). A cache
  keeps the owner it was created with: hence ids of their own. A
  root-owned binary can't be rewritten by the server.
- **Server test in the build stage:** `scratch` has no shell to run a
  server in the background, and Renovate automerges `golang` and
  upstream bumps on it. It runs the example config through the default
  `CMD`'s path, with a token signed by `openssl` (installed from the
  Debian snapshot): health (`curl --retry-all-errors`: a 406 is not
  "connection refused"), then `CreateRoom` and `ListRooms` on the Twirp
  API, which checks the keys, the auth and the HTTP stack. Media is not
  covered (it needs a WebRTC client): `compose.yml` is the by-hand test.
- **Not upstream's tests:** their single-node integration tests run the
  server inside the test process, and cost a long, flaky build for a
  binary the smoke test already starts.
- **The image holds the binary, Debian's CA bundle** (webhooks, Redis TLS,
  TURN TLS), `LICENSE` and `NOTICE`. Upstream's Alpine image has the
  bundle, a shell and `apk`: none is used by the server, which execs
  nothing.
- **Releases, not tags (`github-releases`):** goreleaser creates the
  release as a draft (`.goreleaser.yaml`, `draft: true`), published by
  hand: Renovate proposes published releases only.
- **No `ENV`, no flag in `ENTRYPOINT`:** the server's variables and
  flags override the config file (`c.IsSet` in
  `pkg/config/config.go`).
- **`CMD ["--config", "/etc/livekit/config.yaml"]`:** upstream's image
  has a bare entrypoint and `LIVEKIT_CONFIG`; the file is the common
  case with Compose and Kubernetes ConfigMaps. `LIVEKIT_CONFIG` still
  wins over it.
- **No volume:** the server writes nothing (only `--cpuprofile` and
  `--memprofile` write), state is in memory or Redis.
- **UDP 7882 in the example:** a single port, as `--dev` does, which is
  easy to publish; upstream's default outside `--dev` is 50000-60000.
- **Host network in `compose.yml`:** the server advertises its
  interfaces' addresses (`rtcconfig` `resolveNodeIP`); a bridge would
  advertise the container's. `stop_grace_period` of 10 minutes: SIGTERM
  waits for participants to leave, and a second signal forces.
- **Key file:** absolute path, mode without bits for others
  (`ErrKeyFileIncorrectPermission`, `pkg/config/config.go`); `~` goes
  through go-homedir, which can exec a shell.
- **No `HEALTHCHECK`, no `WORKDIR`:** nothing in the image can run a
  check, and every path is absolute.
