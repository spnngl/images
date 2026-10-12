# haproxy: references

## Sources

- Upstream: `git.haproxy.org/git/haproxy-<line>.git` at tag
  `v<BASE_VERSION>`: `INSTALL` (build options), `Makefile`
- Releases per line: <https://www.haproxy.org/download/>
- Docs: <https://docs.haproxy.org/>
- Official image: `github.com/docker-library/haproxy`, `Dockerfile`
  of each line (build options, user)
- Dalec: `containers/sabnzbd/REFERENCES.md`;
  `targets/linux/deb/distro/container.go` for the image's cleanup

## Decisions

- **Dalec, not a Containerfile:** HAProxy needs distro packages at
  runtime (OpenSSL, PCRE2, Lua and its modules), the case Dalec covers
  (containers/AGENTS.md). Each is a Debian package the SBOM and the
  scanners see. Its packages follow the archive, not the snapshot.
- **One git repository per release line**, as upstream publishes them:
  the spec derives it from `BASE_VERSION` (`${BASE_VERSION%.*}`), and
  `docker-bake.hcl` has one Renovate entry per line (`extractVersion`
  keeps each within its line).
- **The official image's build options:** what most HAProxy containers
  run. `USE_PTHREAD_EMULATION` trades some observability for faster
  locks under OpenSSL 3 (`INSTALL`).
- **Lua modules from Debian** (`lua-json`, `lua-lpeg`): configs of the
  deployments load them.
- **No passwd entry for UID 99:** Dalec's `users` takes no UID, and
  HAProxy runs as a number. `createDirectories` sets the owners of
  `/etc/haproxy` and `/var/lib/haproxy`.
- **`libmd0` as a runtime dependency:** Dalec 0.22.1 purges dpkg's
  libraries before purging the cleanup tools with dpkg, so that purge
  fails (`libmd.so.0: cannot open shared object file`) and leaves
  dash, coreutils and grep in the image. Kept, dpkg runs and they go.
