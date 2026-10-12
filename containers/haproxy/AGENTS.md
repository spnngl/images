# haproxy

HAProxy from source, built with Dalec from `spec.yml` like
`containers/sabnzbd`: one Debian trixie package, installed with the
libraries it links and Debian's Lua modules. One image per release line
(`docker-bake.hcl`). Runtime contract: the spec's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **UID/GID 99, the official image's:** haproxy-ingress shares files
  with an external haproxy under that user. The one exception to the
  65532 rule of [containers/AGENTS.md](../AGENTS.md).
- **A Lua module the configs load is a runtime dependency** in
  `spec.yml`, with a `require` in the `haproxy loads lua-json` test.
  Linked libraries need nothing: the package's shlibs pull them in.
- **Done when** the build passes: its tests run in the final image, and
  `/bin/sh` is absent from it (`docker create`, then `docker export |
  tar -t`).

## Updates

Renovate moves each line within itself (`extractVersion`); patch
releases are automerged. The checksum is the tag's peeled commit (tags
are annotated): Renovate fills it in. To add a line (a new release, or
an older one): copy a `base` entry in `docker-bake.hcl`, with its
`# renovate:` comment (`depName`, `packageName`, `extractVersion` for
that line), and the checksum from
`git ls-remote <repository> refs/tags/v<version>^{}`. To drop a line:
delete its entry; its tags stay in the registry. A release note is at
`https://www.haproxy.org/download/<line>/src/CHANGELOG`. On a Dalec
update, check whether `libmd0` can leave the runtime dependencies
(REFERENCES.md).
