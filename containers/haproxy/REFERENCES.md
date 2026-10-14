# haproxy: references

## Sources

- Upstream: `git.haproxy.org/git/haproxy-<line>.git` at tag
  `v<BASE_VERSION>`: `INSTALL` (build options, 4.11 QUIC), `Makefile`;
  mirror `github.com/haproxy/haproxy`
- Releases per line: <https://www.haproxy.org/download/>
- Docs: <https://docs.haproxy.org/> (`limited-quic`)
- Official image: `github.com/docker-library/haproxy`, `Dockerfile`
  of each line (build options, user)
- `github.com/wiremind/container-images`,
  `images/haproxy/Containerfile.debian13-gcr`: the distroless shape this
  image started from
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc/` and
  `base/` (what `cc-debian13` holds, `/var/lib/dpkg/status.d`)
- GeoLite2: `github.com/P3TERX/GeoLite.mmdb`,
  `.github/workflows/GeoLite.yml` (MaxMind's databases every 3 days, the
  last 2 releases kept); Renovate's `github-release-attachments`
  datasource (`lib/modules/datasource/github-release-attachments`: the
  digest of each file)
- Cloudflare's IP ranges: <https://www.cloudflare.com/ips/>
  (`ips-v4`, `ips-v6`)

## Decisions

- **A Containerfile on distroless, not Dalec:** distroless' `cc-debian13`
  has glibc, libgcc_s (glibc's thread cancellation loads it) and
  OpenSSL; the build stage adds the few packages it lacks. Smaller than
  Dalec's image, and no dpkg workaround (Dalec 0.22.1 needed `libmd0` to
  remove the shell).
- **Debian's libraries, linked dynamically, not static:** OpenSSL, PCRE2,
  Lua and libcrypt stay Debian packages that the SBOM and the scanners see
  (`syft` lists them). The ones distroless lacks are copied with their
  files, status and md5sums into `/var/lib/dpkg/status.d/`, distroless'
  own format. OpenSSL is distroless': its digest, which Renovate moves,
  brings its fixes. Wiremind's image links them statically instead,
  invisible to scanners.
- **Build stage on trixie-slim**, distroless' `cc-debian13` release, with
  packages from the snapshot (containers/AGENTS.md): the copied libraries
  and the ones the binary is built against match the final image's
  Debian release. trixie-slim's dpkg excludes docs but the copyright, so
  only the copyright files ship.
- **QUIC on every line, native from 3.2:** HAProxy uses OpenSSL 3.5's QUIC
  API from v3.2.0 (commit `dc6a3c329`, `HAVE_OPENSSL_QUIC` in
  `include/haproxy/openssl-compat.h`), with 0-RTT; trixie has OpenSSL
  3.5. 2.8 and 3.0 don't: they get `USE_QUIC_OPENSSL_COMPAT=1`, no 0-RTT,
  and their configs need `limited-quic` (ignored by native builds).
  Wiremind's image uses the compatibility layer below 3.3.
- **The official image's build options:** what most HAProxy containers
  run. `USE_PTHREAD_EMULATION` trades some observability for faster
  locks under OpenSSL 3 (`INSTALL`). Upstream's defaults for the rest
  (SLZ, DEBUG's runtime checks), not wiremind's `USE_ZLIB` and `DEBUG=`.
- **Debian's hardening flags** (`dpkg-buildflags`: stack protector,
  fortify, stack clash, branch protection, RELRO), as Debian's packages
  build: upstream's Makefile sets none, and ignores `CFLAGS` from the
  environment. Not `BIND_NOW`, off by default in Debian. Without `-g`
  (`DEB_CFLAGS_MAINT_STRIP`, and upstream's `ARCH_FLAGS` or 2.8's
  `DEBUG_CFLAGS` emptied): no debug info; the symbol table stays, for the
  backtraces HAProxy logs on a crash. The build stage checks them on the
  binary.
- **Master-worker (`-W -db`)**, as the official image runs: the master,
  PID 1, reaps its children and reloads the workers on SIGUSR2 without a
  restart; SIGUSR1 stops them softly.
- **`/usr/sbin/haproxy`**, wiremind's path, where Debian's package puts
  it.
- **Lua modules from Debian** (`lua-json`, `lua-lpeg`): configs of the
  deployments load them. lua-json's 5.4 files are links to its 5.1 ones:
  the whole package is copied.
- **No passwd entry for UID 99:** HAProxy runs as a number, and needs no
  name.
- **Smoke tests:** the build stage serves through lua-json over HTTP/1.1
  and HTTP/3 (trixie's curl has HTTP/3 over OpenSSL), and the Prometheus
  exporter: the build itself and QUIC. The final image runs `haproxy -c`
  on the same config, in exec form (no shell): the linked libraries and
  the copied Lua modules are found there; `-dW` fails it on a warning
  too. The config's `.if` blocks (`version_atleast`, `feature`, both in
  2.8) keep it free of warnings on every line.
- **Lists in `/data/lists`, the last layer** (`COPY --link` of a
  `scratch` stage), for the deployments' configs: they change more
  often than the rest, whose layers stay. Root's: files 0644, folders
  0755 (`--chmod=u=rwX,go=rX`: `ADD` gives a URL's file 0600, and
  `--chmod` also sets the folders it creates).
- **GeoLite2 from P3TERX, pinned:** MaxMind's own downloads need a
  license key, a build secret. Its releases are deleted within about 6
  days, so Renovate takes each one at once and automerges it, its
  `--checksum` the sha256 Renovate computes (the regex manager's
  `currentDigest`): one entry per file, one PR for the three. Renovate
  reads the pinned release to find each file's new digest: once it is
  deleted, only a manual update fixes the build (AGENTS.md, Updates).
  Redistributing GeoLite2 in a public image: accepted by the owner,
  MaxMind's license notwithstanding.
- **Cloudflare's lists, not pinned:** no version to pin; BuildKit
  fetches them again when they change, so a build, and the weekly
  rebuild, has the current ones. The smoke tests check they aren't
  empty and load them as ACLs: an HTML page or a bad range fails the
  build.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments'.
