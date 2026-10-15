# cs-haproxy-spoa-bouncer: references

## Sources

- Upstream: `github.com/crowdsecurity/cs-haproxy-spoa-bouncer` at tag
  `v<BASE_VERSION>`: `Makefile` (release build), `Dockerfile` (image
  layout), `cmd/root.go` (startup, config, shutdown), `config/` (default
  config, HAProxy and SPOE examples)
- Its libraries, at `go.mod`'s versions: `github.com/crowdsecurity/go-cs-bouncer`
  (`stream_bouncer.go`: `retry_initial_connect`),
  `github.com/crowdsecurity/go-cs-lib` (`csyaml`: the `.local` merge,
  `csstring`: `${VAR}` expansion), `github.com/dropmorepackets/haproxy-go`
  (SPOP agent)
- SPOP: `doc/SPOE.txt` in `github.com/haproxy/haproxy`
- Docs: <https://docs.crowdsec.net/u/bouncers/haproxy_spoa>

## Decisions

- **Fail-open:** HAProxy must keep serving when the bouncer or the LAPI
  fails. `retry_initial_connect: true` serves SPOA from start, before
  the first pull succeeds; upstream's default exits instead. The rest is
  upstream's behaviour (AppSec errors allow, bans kept across LAPI
  errors) and HAProxy's config (`AGENTS.md`).
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build. The
  tag is lightweight: `git ls-remote` gives the commit, kept with the
  version by Renovate. The source has no `.git`: the build passes
  `BUILD_VERSION` and `BUILD_TAG` to the Makefile, so `--version` prints
  `v<BASE_VERSION>-<commit>` as upstream's build does.
- **Upstream's release build** (`make binary`: static, `netgo`,
  `-trimpath`), with `DOCKER_BUILD` as upstream's image. The `golang`
  image's Go, newer than `go.mod`'s: the standard library's fixes.
- **Built and tested as UID 65532,** Go cache ids of their own
  (`containers/minio`): upstream code runs in the test, as the image
  does. A root-owned binary can't be rewritten by the bouncer.
- **Server test in the build stage, against a fake LAPI**
  (`smoke-test-lapi.go`, standard library only) **and SPOP in bash:**
  releases and `golang` bumps are automerged on it. It covers what this
  image adds: fail-open at start, then a ban pulled and kept. HAProxy
  isn't in the test: its SPOE is HAProxy's own code, not this image's.
- **Config at the path of upstream's packages,
  `/etc/crowdsec/bouncers/crowdsec-spoa-bouncer.yaml`,** with
  overrides in one `.yaml.local` file: upstream's docs apply, and an
  override keeps `retry_initial_connect` unless it sets it. Only the LAPI's URL and
  key from the environment (`CROWDSEC_URL`, `CROWDSEC_KEY`): the key is
  a secret, and any other setting is an override.
- **Logs on stderr** (`log_mode: stdout`, upstream's name), for the
  runtime; upstream's default writes files in `/var/log`, read-only
  here.
- **SPOA on TCP only, `0.0.0.0:9000`:** a Unix socket needs a volume
  shared with HAProxy. Metrics on `0.0.0.0:6060`, as upstream's image
  exposes; reachable by whoever reaches the pod, like 9000.
- **The image holds the binary, Debian's CA bundle** (an `https` LAPI
  or AppSec), the config, `LICENSE`, and upstream's Lua scripts and
  HTML templates at upstream image's paths, for HAProxy. No `VOLUME`:
  upstream's are for sharing those with HAProxy, which a named volume
  or a Kubernetes image volume does without, and `/run` and `/var/log`
  are unused here. No challenge listener (9100): off in the default
  config.
- **No `HEALTHCHECK`:** nothing in the image can run a check.
