# haproxy

HAProxy built from source with OpenSSL, PCRE2, Lua, zlib, zstd and
libcrypt linked statically, on `gcr.io/distroless/base-debian13`: only
glibc stays dynamic. One image per release line (2.8, 3.0, 3.2, 3.4),
listed in `docker-bake.hcl`; each has a tag for its version and one for
its line (`haproxy:3.2.25-debian13`, `haproxy:3.2-debian13`). Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `ENTRYPOINT ["/usr/sbin/haproxy"]`, `CMD ["-db", "-f", "/etc/haproxy"]`:
  arguments are HAProxy's. The config is the deployment's (a volume).
- **UID/GID 99, not 65532:** haproxy's in the Debian packages;
  haproxy-ingress shares files with an external haproxy under that
  user. The one exception to the 65532 rule of
  [containers/AGENTS.md](../AGENTS.md).
- A difference between release lines goes in the Containerfile as a
  `case` on `BASE_VERSION` (like `USE_QUIC_OPENSSL_COMPAT`, which only
  releases before 3.3 need), never as a second Containerfile.
- The last stage's `RUN ["/usr/sbin/haproxy", "-vv"]` is the smoke test:
  the binary runs, with its Lua and SSL.

## Updates

Renovate follows each line's own git repository
(`https://git.haproxy.org/git/haproxy-<line>.git`, `datasource=git-tags`):
a line moves within itself only, patch releases are automerged. The
checksum is the tag's commit, peeled (tags are annotated): Renovate fills
it in. To add a line (a new release, or an older one): copy a `base`
entry in `docker-bake.hcl`, with its `# renovate:` comment (`depName`,
`packageName`, `extractVersion` for that line), and the checksum from
`git ls-remote <repository> refs/tags/v<version>^{}`. To drop a line:
delete its entry; its tags stay in the registry. A release note is at
`https://www.haproxy.org/download/<line>/src/CHANGELOG`.
