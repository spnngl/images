# haproxy: references

## Sources

- Upstream: `git.haproxy.org/git/haproxy-<line>.git` at tag
  `v<BASE_VERSION>`: `INSTALL` (build options), `Makefile`
- Releases per line: <https://www.haproxy.org/download/>
- Docs: <https://docs.haproxy.org/>

## Decisions

- **One git repository per release line**, as upstream publishes them:
  the Containerfile derives it from `BASE_VERSION` (`${BASE_VERSION%.*}`),
  and `docker-bake.hcl` has one Renovate entry per line
  (`extractVersion` keeps each within its line).
- **Commit pinned** (`ADD --checksum`, the peeled commit of the
  annotated tag): a moved tag fails the build.
- **`debian:trixie` build stage, not `dhi.io`:** CI has no dhi.io login.
  The release is the final image's (distroless `base-debian13`), so the
  glibc matches.
- **Packages from Debian's snapshot** (`DEBIAN_SNAPSHOT_VERSION`):
  `apt-get --snapshot` is not in trixie's apt (3.0.3), so the sources
  are rewritten to `snapshot.debian.org`. A build is repeatable, Renovate
  moves the snapshot.
- **Static OpenSSL, PCRE2, Lua, zlib, zstd, libcrypt:** only glibc is
  left for distroless/base to provide. `SSL_LDFLAGS`, `LUA_LDFLAGS` and
  `ADDLIB` replace the Makefile's because `-Bstatic` must come before
  the libraries in the link order.
- **`USE_QUIC_OPENSSL_COMPAT` before 3.3:** earlier lines have no native
  QUIC on OpenSSL.
- **Lua modules from Debian** (`lua-json`, `lua-lpeg`): configs of the
  deployments load them.
- **UID 99:** see [AGENTS.md](AGENTS.md).
- **`HEALTHCHECK` runs `haproxy -c`:** distroless has no shell nor curl.
