# redis: references

## Sources

- Upstream: `github.com/redis/redis` at tag `<BASE_VERSION>`:
  `src/Makefile` (build flags: `BUILD_TLS`, `BUILD_COMPRESSION`,
  `USE_SYSTEMD`, `OPTIMIZATION`, `DEBUG`; `.make-settings`, the flags
  recorded), `deps/Makefile` (jemalloc's configure line, the flags each
  dependency gets),
  `modules/modules.yaml` (the bundled modules), `SECURITY.md` (lines in
  support), `LICENSE.txt` or `COPYING`
- Official images: `github.com/redis/docker-library-redis`, branch
  `release/<line>`, `debian/Dockerfile` (8.x: build options, jemalloc,
  compression); `github.com/docker-library/redis`, `<line>/debian/Dockerfile`
  (7.2: the jemalloc `sed`)
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc/` and
  `base/` (what `cc-debian13` holds, `/var/lib/dpkg/status.d`)
- `containers/haproxy`: the distroless shape this image copies

## Decisions

- **A Containerfile on distroless, not Dalec:** a C binary linking a few
  Debian libraries (containers/AGENTS.md). `cc-debian13` has every
  library Redis links: glibc, libstdc++ (8.x's fast_float), OpenSSL and
  its dependencies, libzstd1 (8.10's compression) and zlib1g. Nothing is
  copied; the final image's smoke test fails on a missing one.
- **Debian's libraries, linked dynamically:** OpenSSL and libzstd stay
  Debian packages that the SBOM and the scanners see; OpenSSL is
  distroless', its digest brings its fixes. jemalloc, Lua and hiredis
  are upstream's vendored copies (`deps/`), as every upstream build.
- **Every line upstream patches from 6.2, but 7.4** (each gets a
  release in the same batch; `SECURITY.md`'s table lags the newest
  lines). 6.2 and 7.2 are BSD-3-Clause, 8.x adds AGPLv3 to RSALv2 and
  SSPLv1; the label and `/usr/share/doc/redis/` follow the line. 7.4 is
  RSALv2 or SSPLv1 only (source-available, not open source), and 8.2
  replaces it.
- **Core only:** the bundled modules (search, JSON, time series, bloom)
  need Rust, cmake and clang, and clone their sources at build time,
  each a version to pin. Vector sets are in-tree and in 8.x's core.
- **The official image's build options:** `BUILD_TLS=yes` (TLS in the
  server, not as a module), `BUILD_COMPRESSION=yes` from 8.10
  (replication compression, libzstd), jemalloc (upstream's default on
  Linux) configured with Debian's page sizes: 4 KiB on amd64, 64 KiB
  elsewhere, so arm64 kernels with 64 KiB pages run it; a build host's
  detected size would crash them (jemalloc/jemalloc#467). Added to
  `deps/Makefile`'s configure line with the official image's `sed`, on
  every line: 6.2's has no `JEMALLOC_CONFIGURE_OPTS`. A `grep` checks the
  edit; the smoke test reads the size back from `MEMORY MALLOC-STATS`.
- **`USE_SYSTEMD=no`:** sd_notify has no listener in a container; the
  build has no libsystemd to detect anyway.
- **No protected-mode patch:** the official image patches the default to
  off; here a config is mandatory, and upstream's default stays: a config
  sets a password or turns it off.
- **Debian's hardening flags** (`dpkg-buildflags`: stack protector,
  fortify, stack clash, branch protection, RELRO), as Debian's packages
  build, through `CFLAGS` and `LDFLAGS` from the environment, which
  `src/Makefile` and `deps/Makefile` append to their own. Without
  Debian's `-O2`, which would override upstream's `-O3` and LTO. Debug
  info stripped (`strip --strip-debug`, after upstream's `-g -ggdb`); the
  symbol table stays for the backtraces Redis logs on a crash. The build
  stage checks them on the binary.
- **`make -C src`:** the same build on every line; 8.10's top-level
  Makefile adds module orchestration this image doesn't use.
- **Binaries:** `redis-server`, `redis-cli` (exec probes), and
  `make install`'s links to the server (`redis-sentinel`,
  `redis-check-aof`, `redis-check-rdb`, chosen by name).
  `redis-benchmark` removed: a load generator, not part of a server.
  `/usr/local/bin`, the official images' path.
- **Config in `/etc/redis/redis.conf`, a volume, writable by the user:**
  `CONFIG REWRITE` and Sentinel write their config back. None shipped:
  the deployment's. **Data in `/data`**, the official images' path and
  the working folder, so upstream's default `dir ./` lands there.
- **UID/GID 65532** (containers/AGENTS.md), not the official images' 999.
- **Smoke tests:** the build stage runs the server as the image's user
  with a throwaway password and certificate, writes over TCP and reads
  over TLS: the build itself, TLS and the version. The compression
  config answers when `.make-settings` records `BUILD_COMPRESSION=yes`:
  the version check stays in one place, the build flag. A Sentinel
  monitoring the server reads its run ID: the link, the config it
  rewrites, `auth-pass`. The final image runs
  `redis-cli --version` and `redis-check-rdb` on the build's dump, in exec
  form (no shell): the libraries are found there, and the links work.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments'.
