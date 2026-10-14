# haproxy

HAProxy from source, a Containerfile on distroless' `cc-debian13`: the
binary, linked against Debian trixie's libraries, and the Debian packages
it needs that distroless lacks, copied with their dpkg status, and lists
in `/data/lists` (GeoLite2 databases, Cloudflare's IP ranges). One image
per release line (`docker-bake.hcl`). Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
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
  checks it (`-c`, its libraries, Lua modules and the Cloudflare lists
  as ACLs), and `/bin/sh` is
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

GeoLite2: P3TERX publishes a release every 3 days and deletes it, tag
included, once two newer exist; Renovate automerges each one, with no
wait (`renovate.json5`), and each file's checksum is the sha256 Renovate
computes. A pinned release that is gone fails every line's build (`ADD`
returns 404), and Renovate can no longer update it (it reads the pinned
release to map each file's digest): set the three entries of
`geolite2` in `docker-bake.hcl` to the newest release, with each file's
sha256 from
`gh api repos/P3TERX/GeoLite.mmdb/releases/latest --jq '.assets[] | .name + " " + .digest'`.
Cloudflare's lists are not pinned: each build fetches the current ones.
