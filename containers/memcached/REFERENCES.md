# memcached: references

## Sources

- Upstream: `github.com/memcached/memcached` at tag `<BASE_VERSION>`:
  `autogen.sh` and `version.pl` (the version from `git describe`),
  `configure.ac` (`--enable-tls`, extstore on by default),
  `Makefile.am` (the sources built in, `vendor/mcmc` among them),
  `memcached.c` (option defaults, `--help`'s EXPERIMENTAL marks, `-Y`
  refusing the binary protocol, signal handlers, `clock_handler`'s
  SIGHUP reload, the saved cache dropped with extstore), `restart.c`
  (the memory file and its `.meta`), `proto_text.c` (the authentication
  replies), `proto_bin.c` (the binary protocol deprecated as of 1.6.0),
  `base64.c` and `daemon.c` (their BSD notices), `vendor/fetch.sh` (the
  proxy's download), `t/extstore.t` (filling extstore),
  `doc/protocol.txt`
- Releases: `github.com/memcached/memcached.wiki`, `ReleaseNotes<version
  without dots>.md`
- Docs: <https://docs.memcached.org> (TLS, extstore, authentication,
  restartable cache)
- Official image: `github.com/docker-library/memcached`,
  `1/debian/Dockerfile` (configure options, `make test`) and
  `docker-entrypoint.sh`
- SBOM: `github.com/anchore/syft`,
  `syft/pkg/cataloger/binary/classifiers.go` (`memcached-binary`)
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc/` and
  `base/` (what `cc-debian13` holds)

## Decisions

- **A Containerfile on distroless, libevent copied:** Memcached is a C
  binary linking glibc, OpenSSL and libevent; `cc-debian13` lacks only
  libevent. One package copied with its dpkg status, as
  `containers/haproxy` does, keeps it visible to scanners and moved by
  the snapshot Renovate updates. Dalec would rebuild the whole runtime
  for one library.
- **The latest release only:** Memcached has one maintained line.
- **The git tag, not the release tarball:** `--checksum` pins the tag's
  commit, which Renovate fills in from `github-tags`; a tarball's
  digest it can't. The checkout lacks the tarball's generated files,
  so the build runs `autogen.sh` (autoconf, automake).
- **`--keep-git-dir`, not a written `version.m4`:** `version.pl` reads
  the version with `git describe`, as upstream's own build does; the
  commit is already checked by `--checksum`. Without `.git`, Memcached
  reports `UNKNOWN`, and syft finds no version.
- **TLS and extstore built in:** as the official image. TLS links the
  OpenSSL distroless ships; extstore links nothing.
- **No SASL; the authfile instead:** SASL serves the binary protocol
  only, deprecated as of 1.6.0 (`proto_bin.c`), and needs libsasl2, its
  modules and its database copied in. The authfile (`-Y`, EXPERIMENTAL
  upstream) authenticates the text and meta protocols with no library;
  with it, Memcached refuses the binary protocol.
- **No proxy (`--enable-proxy`):** it builds Lua and routelib from a
  `memcached-vendor` archive that `vendor/fetch.sh` downloads and checks
  with a SHA-1, outside `--checksum` and Renovate. A proxy deployment is
  a different image.
- **No seccomp (`--enable-seccomp`):** EXPERIMENTAL upstream, and it
  links libseccomp, one more library to copy.
- **Debian's hardening flags** (`dpkg-buildflags`: stack protector,
  fortify, stack clash, branch protection, RELRO; not BIND_NOW, off by
  default, as the repository's other C images), passed to
  `configure`, `-g` stripped (`DEB_CFLAGS_MAINT_STRIP`): no debug info;
  the symbol table stays, to name a crash's frames. The build stage
  checks the binary for no debug info, a symbol table,
  `__stack_chk_fail` and fortify's `_chk` functions.
- **Built and tested as UID 65532:** neither the build nor the server
  gets root; the source is copied to a folder the user owns, so git
  reads it without `safe.directory`.
- **The `memcached` target alone:** plain `make` also builds the test
  programs, unused here.
- **Licenses:** upstream's and those of the code built in (bipbuffer,
  itoa_ljust, mcmc, and the BSD notices in `base64.c`'s and
  `daemon.c`'s headers, cut out with `sed` as `containers/valkey` does
  linenoise's), in `/usr/share/doc/memcached/`. `crc32c.c`'s zlib
  license asks no notice in a binary.
- **UID 65532, not the official image's 11211:** the repository's rule
  (containers/AGENTS.md); Memcached writes no file unless told to, so
  no data folder is owned.
- **`ENTRYPOINT` memcached, no `CMD`, no entrypoint script:** the
  official script only prepends `memcached` when the first argument is
  an option; the container's arguments are the server's here. With
  none, upstream's defaults.
- **`/usr/bin`**, where Debian's package puts the binary.
- **Default stop signal, SIGTERM:** Memcached exits at once, the cache
  is memory. A deployment with a restartable cache (`-e`) sets SIGUSR1,
  which saves it first: the image has no shell for a `preStop` `kill`,
  so the header names each runtime's stop-signal setting. One image
  serves both.
- **The restartable cache on a tmpfs:** upstream's `--help` says
  "use only in ram disks or persistent memory mounts". It survives a
  container restart, not a reschedule. With extstore, Memcached prints
  `memory restart with extstore not presently supported` and starts
  empty, so the header says the two exclude each other.
- **`-m` bounds the items alone:** connections, threads and extstore's
  buffers come on top, so the header tells deployments to set the
  memory limit above it.
- **Probes over TCP:** with an authfile, even `version` gets
  `CLIENT_ERROR unauthenticated`.
- **Smoke tests:** the build stage runs the server as the image's user
  with an authfile (random password), a plain and a TLS listener (a
  throwaway self-signed certificate) and extstore: a client refused
  before it authenticates, a key written over TCP and read back over
  TLS with the certificate verified, 1000 values of 20 KB until
  extstore has written half to its file (upstream's `t/extstore.t`
  asserts the same) and serves the first back, then a new authfile and
  certificate on SIGHUP: a TLS client verifying the new certificate,
  and the old password refused. Before it, a `-B binary` start with an
  authfile, which must exit with `EX_USAGE`. A second server, a
  restartable cache without extstore: a key written, saved on SIGUSR1
  and read back after a restart. Exit status 0 on SIGTERM and SIGUSR1.
  These are the runtime contract's features, each one a reload or file
  path a release can break. Upstream's `make test` (Perl, minutes) is
  left to upstream's CI. Patch and minor releases automerge on it. The
  final image runs `--version` in exec form: the binary finds its
  libraries there.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments'.
