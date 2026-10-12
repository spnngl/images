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
  Same release as distroless `cc-debian13`: the binary runs with the
  libraries it was linked against.
- **Linked dynamically, on distroless `cc`:** OpenSSL, zlib, zstd and
  libstdc++ (Lua's) come from distroless, the rest from Debian
  packages. Each library is then a package the SBOM and the scanners
  see, moved by the snapshot and the base digest. A static build hides
  OpenSSL from both and needs per-architecture link flags.
- **The official image's build options:** what most HAProxy containers
  run. `USE_PTHREAD_EMULATION` trades some observability for faster
  locks under OpenSSL 3 (`INSTALL`).
- **Lua modules from Debian** (`lua-json`, `lua-lpeg`): configs of the
  deployments load them.
- **No `HEALTHCHECK`:** `haproxy -c` checks the config, not the
  process, and Kubernetes ignores it.
