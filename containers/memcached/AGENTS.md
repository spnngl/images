# memcached

Memcached from source, a Containerfile on distroless' `cc-debian13`:
the binary, TLS and extstore built in, linked against the OpenSSL
distroless ships and Debian trixie's libevent, copied with its dpkg
status. The latest release only. Runtime contract: the Containerfile's
header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **A runtime library** distroless lacks is copied with its dpkg status
  (the libevent `RUN`); a build option that links another (SASL's
  libsasl2, seccomp's libseccomp) brings one more such copy, and the
  smoke test exercises it.
- **The version** comes from `git describe` (upstream's `version.pl`),
  hence `--keep-git-dir`: the smoke test's first line checks it.
- **Done when** the build passes: the build stage's smoke test (the
  version, the hardening, the binary protocol refused with an authfile,
  an unauthenticated client refused, a key
  written over TCP and read over TLS, values read back from extstore,
  a new password and certificate taken on SIGHUP, a key kept across a
  SIGUSR1 restart, exit status 0), `--version` in the final image,
  `/bin/sh` absent from it (`docker create`, then
  `docker export | tar -t`), and `syft <image>` listing
  `memcached <BASE_VERSION>` and `libevent-2.1-7t64`, on amd64 and
  arm64.

## Updates

Renovate proposes each `x.y.z` tag and fills in the checksum, the tag's
peeled commit (tags are annotated). Patch and minor releases are
automerged on the smoke test; a major waits for review. Release notes:
`https://github.com/memcached/memcached/wiki/ReleaseNotes<version>`,
the version without dots (`ReleaseNotes1645`). A failing reply check
means upstream changed that reply's text (`proto_text.c`): update the
expected string. A failing restart means upstream changed the
restartable cache (`restart.c`, `memcached.c`'s `-e`): read its release
notes. A failing license cut means upstream changed `base64.c`'s or
`daemon.c`'s header: fix the `sed` range. A distroless digest update
keeps trixie; moving to Debian 14 changes both `FROM` lines and, with a
new soname, libevent's package name.
