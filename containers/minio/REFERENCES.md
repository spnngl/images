# minio: references

## Sources

- Upstream: `github.com/minio/minio` at tag `<BASE_VERSION>`
  (`RELEASE.<date>T<time>Z`): `Makefile` and
  `buildscripts/gen-ldflags.go` (release build), `cmd/` (flags and
  variables)
- Docs: `github.com/minio/docs`

## Decisions

- **The last release, without patches:** fixes merged after the last
  tag (a PostPolicy tag check among them) aren't in the image.
- **Known vulnerabilities, accepted:** advisories published after the
  archive have no open-source fix, in MinIO's code among them:
  unauthenticated object writes through unsigned-trailer uploads
  (CVE-2026-40344, CVE-2026-41145), OIDC JWT algorithm confusion
  (CVE-2026-33322), LDAP user enumeration (CVE-2026-33419). Its
  dependencies stay at the tag's versions. Backports would be a fork to
  maintain; `containers/silo` and `containers/garage` are the
  maintained S3 stores.
- **Commit pinned** (`ADD --checksum`): MinIO holds the data, and the
  tag is all that is left to trust. buildah ignores `--checksum` for git
  and its docker-client backend refuses `--keep-git-dir`: CI's BuildKit
  build is the one that counts.
- **Upstream's release build:** `go build -tags kqueue -trimpath` with
  the ldflags of `gen-ldflags.go`, which reads the commit with git
  (hence `--keep-git-dir`) and the tag's time, so `--version` prints the
  release and commit, not `DEVELOPMENT.GOGET`. The `golang` image's Go,
  newer than `go.mod`'s: the standard library's fixes.
- **Built and tested as UID 65532:** upstream code runs in the build
  (`gen-ldflags.go`, the server), and the test runs MinIO as the image
  does. The source stays root's, trusted by git through a system
  `safe.directory` set while root. A cache keeps the owner it was
  created with, so root's (cs-firewall-bouncer) aren't writable: hence
  ids of their own. A root-owned binary can't be rewritten by MinIO.
- **Server test in the build stage:** a single-drive server with random
  credentials, a bucket, a 1 MiB object written and read back through
  the S3 API (`curl --aws-sigv4`), then a graceful stop. Renovate
  automerges `golang` bumps, and nobody upstream tests this code with a
  newer Go.
- **The image holds the binary, Debian's CA bundle** (OpenID, LDAP,
  KMS, replication, notification targets), `LICENSE` and `CREDITS`. Not
  distroless: its extras are unused by MinIO, and its Debian release is
  in the image name, which Renovate can't follow.
- **`MINIO_UPDATE=off`:** no update check against `dl.min.io` at start,
  and `mc admin update` can't replace the pinned binary.
- **`/certs`:** MinIO's default, `~/.minio/certs`, depends on `HOME`.
  Without a key pair there, it serves plain HTTP.
- **No `HEALTHCHECK`, no `WORKDIR`:** nothing in the image can run a
  check, and every path is absolute.
