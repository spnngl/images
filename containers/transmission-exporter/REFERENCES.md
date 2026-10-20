# transmission-exporter: references

## Sources

- Upstream: `github.com/spnngl/transmission-exporter` at tag
  `v<BASE_VERSION>`: `Makefile` (build), `cmd/transmission-exporter/main.go`
  (variables, `--version`), `transmission.go` (RPC client),
  `cmd/transmission-exporter/AGENTS.md` (metrics, 500 on a failed RPC
  call)
- Transmission's RPC: `github.com/transmission/transmission`,
  `docs/rpc-spec.md`

## Decisions

- **One static binary on `scratch`:** `CGO_ENABLED=0` (`Makefile`), and
  the exporter execs nothing.
- **Commit pinned** (`ADD --checksum`): a moved tag fails the build.
- **Upstream's build, version included:** upstream has no release build;
  `main.go` names the flag, `-X main.version=<version>`. `-trimpath`:
  no build paths in the binary. No `.git`: the version needs none.
- **The `golang` image's Go**, newer than `go.mod`'s: the standard
  library's fixes. `GOTOOLCHAIN=local` (the image's): a `go.mod` asking
  for a newer Go fails the build instead of downloading a toolchain;
  the next `golang` bump fixes it.
- **Built and tested as UID 65532:** neither the exporter nor
  Transmission get root in the build, and the test runs the exporter as
  the image does.
- **Server test against Debian's `transmission-daemon`:** a real RPC
  (session id renewal, basic auth, a torrent added through it) is what a
  release or a `golang` bump can break, and what upstream's unit tests
  fake. It found Transmission 4.1's fractional speed limits, which
  failed every scrape, and speed limits reported in kB/s as bytes. No
  peer: DHT, LPD and port mapping off, a magnet with no tracker, paused.
  The stop is checked too: on SIGTERM the exporter finishes its scrapes
  and exits 0.
- **The image holds the binary, Debian's CA bundle** (an https
  `TRANSMISSION_ADDR`; Go reads `/etc/ssl/certs/ca-certificates.crt`)
  **and `LICENSE`** (MIT: the notice goes with the binary).
- **Credentials in variables:** upstream reads `TRANSMISSION_PASSWORD`
  only, no file variant; on Kubernetes, from a Secret through `env`.
- **No `CMD`, no volume, no `WORKDIR`:** settings are variables, the
  exporter writes nothing. It reads an optional `.env` from its working
  directory, `/`, where the image has none.
- **No `HEALTHCHECK`:** nothing in the image can run a check.
