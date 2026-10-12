# haproxy

HAProxy built from source with the official image's build options, on
`gcr.io/distroless/cc-debian13`, plus the Debian packages it lacks
(PCRE2, Lua, libcrypt, lua-json, lua-lpeg). One image per release line,
listed in `docker-bake.hcl`. Runtime contract: the Containerfile's header.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **UID/GID 99, not 65532:** haproxy's in the official image;
  haproxy-ingress shares files with an external haproxy under that
  user. The one exception to the 65532 rule of
  [containers/AGENTS.md](../AGENTS.md).
- **A runtime library is a Debian package:** add it to the
  `apt-get download` list of the Containerfile, with its dependencies
  that distroless/cc lacks; `/var/lib/dpkg/status.d` then lists it for
  the SBOM and the scanners.
- **A Lua module the deployments load** goes in that list too, and in
  `smoke-test.lua`.

## Updates

Renovate moves each line within itself (`extractVersion`); patch
releases are automerged. The checksum is the tag's peeled commit (tags
are annotated): Renovate fills it in. To add a line (a new release, or
an older one): copy a `base` entry in `docker-bake.hcl`, with its
`# renovate:` comment (`depName`, `packageName`, `extractVersion` for
that line), and the checksum from
`git ls-remote <repository> refs/tags/v<version>^{}`. To drop a line:
delete its entry; its tags stay in the registry. A release note is at
`https://www.haproxy.org/download/<line>/src/CHANGELOG`.
