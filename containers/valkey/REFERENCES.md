# valkey: references

## Sources

- Upstream: `github.com/valkey-io/valkey` at tag `<BASE_VERSION>`:
  `README.md` (build options), `src/Makefile` (flags, `-rdynamic`,
  `BUILD_TLS`, `USE_SYSTEMD`), `deps/Makefile` (how the bundled
  libraries build, `JEMALLOC_CONFIGURE_OPTS`), `deps/README.md`
  (Valkey's jemalloc changes), `src/mkreleasehdr.sh` (git SHA, build
  ID), `src/config.c` (option defaults), `src/server.c`
  (`initServerConfig`: the default save points; `main`: `valkey-check-*`
  chosen by the executable's name)
- Releases: <https://github.com/valkey-io/valkey/releases>; notes in
  `00-RELEASENOTES` at each tag
- Docs: <https://valkey.io/topics/> (security, persistence, TLS)
- Official image: `github.com/valkey-io/valkey-container`,
  `<line>/debian/Dockerfile` (build options, protected-mode patch,
  jemalloc page size) and `docker-entrypoint.sh`
- Debian's jemalloc page sizes: `salsa.debian.org/debian/jemalloc`,
  `debian/rules`
- SBOM: `github.com/anchore/syft`,
  `syft/pkg/cataloger/binary/classifiers.go` (`valkey-binary`)
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc/` and
  `base/` (what `cc-debian13` holds)

## Decisions

- **A Containerfile on distroless, not Dalec or scratch:** Valkey is a
  C binary linking glibc and OpenSSL, both in `cc-debian13`: no package
  to add (containers/AGENTS.md, "Pick the build"). OpenSSL stays a
  Debian package the scanners see, its fixes brought by the distroless
  digest Renovate moves.
- **The latest release line only:** one line to keep; a new line comes
  as a Renovate PR (`extractVersion` takes every `x.y.z` tag), a major
  one reviewed by hand.
- **Bundled libraries (jemalloc, Lua, libvalkey) as upstream builds
  them:** Valkey's jemalloc carries its own changes for active
  defragmentation (`deps/README.md`), and the official image builds
  them so.
- **TLS built in (`BUILD_TLS=yes`), not a module:** as the official
  image; one binary, no module to load.
- **No systemd (`USE_SYSTEMD=no`):** nothing in a container listens to
  `sd_notify`, and distroless has no libsystemd. The official image
  links it.
- **No `USE_FAST_FLOAT`:** 9.1's Makefile has no such option; fast_float
  is a C header built in (`deps/fast_float/ffc.h`). The official image
  still sets it, with `g++`.
- **`valkey-server`, `valkey-cli`, `valkey-check-aof` and
  `valkey-check-rdb`:** the server; the client for exec probes and
  debugging; the checks, symbolic links to `valkey-server` as upstream's
  `make install` adds them, the only way to check or repair a data file
  in an image without a shell. `valkey-sentinel` (a deployment mode of
  its own) and `valkey-benchmark` (a load generator): left out.
- **linenoise's and fast_float's licenses cut from their sources'
  headers:** they ship no license file, and both are linked in.
- **protected-mode off, patched in the source:** as the official image,
  whose `sed` this is: a container's port is reachable only where it is
  published, and access control is `requirepass`, ACL users and the
  network's. In the source, not an argument: the default holds whatever
  arguments the container gets.
- **Debian's hardening flags** (`dpkg-buildflags`: stack protector,
  fortify, stack clash, branch protection, RELRO), through the
  environment: upstream's Makefile appends to `CFLAGS` and hands it to
  the bundled libraries. `-O2` stripped: upstream's `-O3` and LTO stay.
- **Debug info stripped, symbol table kept:** `strip --strip-debug`
  after the build, since jemalloc's configure, libvalkey's and the
  other bundled Makefiles each add their own `-g`. The symbol table and
  `-rdynamic`'s exports name the functions of the stack trace Valkey
  logs on a crash. The build stage checks both, and the hardening, on
  the binaries.
- **jemalloc's page size set, not detected:** jemalloc fixes it at build
  time and aborts on a kernel with larger pages (arm64 with 16 or 64
  KiB). Debian's values, as the official image: 4 KiB on amd64, 64 KiB
  elsewhere; 2 MiB huge pages, not the build host's.
- **Build ID `<host>-<SOURCE_DATE_EPOCH>`, patched in
  `src/mkreleasehdr.sh`:** upstream's is the host name and the time, or
  the bare `SOURCE_DATE_EPOCH` when set. syft's `valkey-binary`
  classifier reads the version from `<version>buildkitsandbox-<digits>`
  (BuildKit's host name): with the bare time, Valkey vanishes from the
  SBOM and the scans. Patched, a rebuild prints the same `build=` and
  syft finds Valkey; the build stage greps the binary for the string.
- **UID 65532, no entrypoint script:** the official script's chown,
  `setpriv` and umask 0077 need a shell. `/data` is the image's user's,
  so a new named volume is too; Kubernetes sets a volume's group with
  `fsGroup`. Files Valkey writes get mode 0644: the volume's permissions
  guard them.
- **`ENTRYPOINT` valkey-server, no `CMD`:** the container's arguments
  are the server's, a config file path first, as upstream's usage
  reads them. With none, Valkey's defaults: `dir` is the working
  directory, `/data`.
- **`/usr/bin`**, where Debian's package puts both binaries.
- **No CA bundle copied:** distroless ships Debian's; Valkey's outbound
  TLS (replication, cluster bus) verifies with `tls-ca-cert-file` or
  `tls-ca-cert-dir`, set by the deployment.
- **Smoke tests:** the build stage runs the server as the image's user
  with a random password over TCP and TLS, AOF on, writes a key, reads
  it back over TLS, through Lua and from a replica synced over TLS,
  stops both with SIGTERM (the stop signal), checks the RDB and AOF
  with `valkey-check-*` and reads the key back after a restart: the
  build, TLS, replication, the static Lua module, persistence and the
  check links. Patch and minor releases automerge on it.
  `valkey-check-aof` checks the incremental file: 9.1's reads the
  manifest's base RDB, signed `VALKEY`, as a broken AOF
  (valkey-io/valkey#4739, in `unstable` only). The final image runs
  both binaries' `--version` in exec form: they find their libraries
  there.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments'.
