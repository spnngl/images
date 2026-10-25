# valkey

Valkey from source, a Containerfile on distroless' `cc-debian13`:
`valkey-server`, `valkey-cli` and the `valkey-check-*` links, TLS built in, linked against the
OpenSSL distroless ships. The latest release line only. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Distroless' libraries only:** the binaries link glibc and OpenSSL.
  A build option that links another library (systemd, RDMA) brings
  haproxy's package loop with it (`containers/haproxy/Containerfile`).
- **protected-mode off** is a patch of `src/config.c`: the `grep` after
  the `sed` and the server test both check it.
- **The build ID** is a patch of `src/mkreleasehdr.sh`, for syft
  (REFERENCES.md): the server test greps the binary for
  `<version>buildkitsandbox-<SOURCE_DATE_EPOCH>`.
- **Done when** the build passes: the build stage's server test (TCP,
  TLS, Lua, a replica synced over TLS, the RDB and AOF saved on SIGTERM,
  checked by `valkey-check-*` and loaded back), both binaries'
  `--version` in the final image, `/bin/sh` absent from it
  (`docker create`, then `docker export | tar -t`), and `syft <image>`
  listing `valkey <BASE_VERSION>`.

## Updates

Renovate proposes each `x.y.z` tag, a new line's included, and fills in
the checksum, the tag's commit (tags are lightweight). Patch and minor
releases are automerged on the server test; a major waits for review:
its release notes (`00-RELEASENOTES` at the tag) name changed defaults
and build options. A failing protected-mode `grep` means upstream
rewrote that line of `src/config.c`, a failing build ID `grep` that of
`src/mkreleasehdr.sh`: update the `sed`; a failing
license `grep`, that linenoise's or fast_float's header changed. From
the first release with valkey-io/valkey#4739, `valkey-check-aof` takes
the AOF manifest: the server test checks it instead of the incremental
file. A distroless
digest update keeps trixie; moving to Debian 14 changes both `FROM`
lines.
