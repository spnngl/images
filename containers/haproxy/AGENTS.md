# haproxy

HAProxy from source, a Containerfile on distroless' `cc-debian13`: the
binary, linked against Debian trixie's libraries, and the Debian packages
it needs that distroless lacks, copied with their dpkg status, and the
`containers/datalists` lists in `/data/lists`, GeoLite2 aside (the SPOA
bouncer's, `containers/cs-haproxy-spoa-bouncer`). One image per release
line (`docker-bake.hcl`). Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **UID/GID 99, the official image's:** haproxy-ingress shares files
  with an external haproxy under that user. The one exception to the
  65532 rule of [containers/AGENTS.md](../AGENTS.md).
- **A runtime package** (a library HAProxy links that distroless lacks,
  a Lua module the configs load) is in the Containerfile's package loop,
  installed in the build stage, and the smoke test uses it: a Lua module
  is `require`d by `smoke-test/smoke-test.lua`.
- **QUIC:** 2.8 and 3.0 build with `USE_QUIC_OPENSSL_COMPAT=1`, later
  lines with OpenSSL's QUIC API; the smoke test checks which, from the
  feature list (a `case` on `BASE_VERSION`, in both `RUN`s).
- **Done when** the build passes: the build stage serves
  `smoke-test/haproxy.cfg` over HTTP/1.1 and HTTP/3, the final image
  checks it (`-c`, its libraries, Lua modules and the Cloudflare and
  ipverse lists as ACLs), and `/bin/sh` is
  absent from it (`docker create`, then `docker export | tar -t`).

## Updates

Renovate moves each line within itself (`extractVersion`); patch
releases are automerged. The checksum is the tag's peeled commit (tags
are annotated): Renovate fills it in. To add a line (a new release, or
an older one): copy a `base` entry in `docker-bake.hcl`, with its
`# renovate:` comment (`depName`, `packageName`, `extractVersion` for
that line), and the checksum from
`git ls-remote <repository> refs/tags/v<version>^{}`. A line older than
3.2 needs the QUIC compatibility layer (Rules). To drop a line: delete
its entry; its tags stay in the registry. A release note is at
`https://www.haproxy.org/download/<line>/src/CHANGELOG`. A distroless
digest update keeps trixie; moving to Debian 14 changes both `FROM`
lines.

The lists: Renovate moves the datalists digest (the `lists` stage's
`FROM`) each time that image is pushed, and automerges it once the
smoke tests pass. A failing one means the lists changed: fix
`smoke-test/haproxy.cfg` or `containers/datalists`.
