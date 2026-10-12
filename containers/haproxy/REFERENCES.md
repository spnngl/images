# haproxy: references

## Sources

- Upstream: `git.haproxy.org/git/haproxy-<line>.git` at tag
  `v<BASE_VERSION>`: `INSTALL` (build options), `Makefile`
- Releases per line: <https://www.haproxy.org/download/>
- Docs: <https://docs.haproxy.org/>
- Official image: `github.com/docker-library/haproxy`, `Dockerfile`
  of each line (build options, user)
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc`
  image (packages, `/var/lib/dpkg/status.d`)

## Decisions

- **One git repository per release line**, as upstream publishes them:
  the Containerfile derives it from `BASE_VERSION` (`${BASE_VERSION%.*}`),
  and `docker-bake.hcl` has one Renovate entry per line
  (`extractVersion` keeps each within its line).
- **`debian:trixie` build stage, not `dhi.io`:** CI has no dhi.io login.
  The release is the final image's (distroless `cc-debian13`), so the
  libraries the binary links against are the ones it runs with.
- **Linked dynamically, on distroless `cc`:** OpenSSL, zlib, zstd and
  libstdc++ (Lua's) come from distroless, the rest from Debian
  packages extracted as distroless does. Each library is then a package
  the SBOM and the scanners see, updated by the snapshot and the base
  digest; static linking hid OpenSSL from both and needed link-order
  overrides of the Makefile.
- **The official image's build options** (`USE_PTHREAD_EMULATION`,
  `USE_GETADDRINFO`, `USE_PROMEX`, PCRE2 JIT...), upstream's defaults
  otherwise: libcrypt for encrypted userlist passwords, SLZ for
  compression, `DEBUG`.
- **QUIC on every line:** native on OpenSSL from 3.2 (OpenSSL 3.5,
  `INSTALL`); `USE_QUIC_OPENSSL_COMPAT` (no 0-RTT) on 2.8 and 3.0.
- **Lua modules from Debian** (`lua-json`, `lua-lpeg`): configs of the
  deployments load them; the smoke test loads lua-json in the final
  image.
- **`strip --strip-debug`:** the symbol table stays, for HAProxy's
  backtraces.
- **No `HEALTHCHECK`:** `haproxy -c` checks the config, not the
  process; Kubernetes ignores it.
