# mailpit: references

## Sources

- Upstream: `github.com/axllent/mailpit` at tag `v<BASE_VERSION>`:
  `.github/workflows/build-release.yml` (release build), `Dockerfile`
  (upstream's image), `cmd/` (flags and `MP_*` variables),
  `config/config.go` (defaults), `internal/storage/database.go`
  (database path)
- Docs: `https://mailpit.axllent.org/docs/`

## Decisions

- **Static binary on `scratch`:** no cgo (`CGO_ENABLED=0`, SQLite is
  `modernc.org/sqlite`) and Mailpit execs nothing: SpamAssassin is
  reached over the network.
- **Commit pinned** (`ADD --checksum`), the source fetched by both
  stages: the Go stage gets only the UI's output from the Node stage.
- **Upstream's release build:** the UI by `npm ci` and `npm run
  package` on Node 22, as its release workflow; then `CGO_ENABLED=0 go
  build -ldflags "-w -X …config.Version=v<BASE_VERSION>"`, so `version`
  prints the tag. The `golang` image's Go, newer than `go.mod`'s: the
  standard library's fixes.
- **UI stage on `$BUILDPLATFORM`:** its output is JavaScript and CSS, the
  same for every platform; a cross build runs Node natively.
- **No `go-licenses` run:** the third-party license page of the UI says
  "not available", as in any source build; one pinned tool less.
- **Built and tested as UID 65532:** npm, the build and the server get
  no root. The source stays root's: only `node_modules`
  and `server/ui/dist` are the user's in the UI stage. A cache keeps the
  owner it was created with: hence ids of their own.
- **Server test in the build stage:** Renovate automerges `golang` bumps
  and Mailpit's minor and patch releases on it.
- **`npm ci --ignore-scripts`:** the UI's output is byte-identical
  without the packages' install scripts, which would run third-party
  code, report installs to scarf.sh (`@scarf/scarf`), and fall back to
  `node-gyp` builds (tree-sitter) the slim Node image can't run.
- **`MP_DATABASE=/data/mailpit.db` and a `/data` volume:** upstream's
  default is a temporary file in `os.TempDir()`, deleted at exit and
  unwritable under `--read-only`. Messages survive a restart.
- **`MP_DISABLE_VERSION_CHECK=true`:** no release check against GitHub;
  the image is the update.
- **The image holds the binary, Debian's CA bundle** (SMTP relay and
  forward, webhooks, link checker, screenshots), **Debian's time zones**
  (`TZ`, the search's `tz`; Go reads `/usr/share/zoneinfo`; trixie's
  `tzdata` has no legacy names such as `US/Eastern`: those are in
  `tzdata-legacy`), and `LICENSE` (MIT). Both from the `golang` image,
  whose digest Renovate moves.
- **`HEALTHCHECK` with `mailpit readyz`:** upstream's; the binary is the
  probe, no shell needed.
- **No `sendmail` links:** upstream's image links the binary as
  `sendmail` for use inside its container; a client container runs its
  own.
- **No `WORKDIR`:** every path is absolute.
