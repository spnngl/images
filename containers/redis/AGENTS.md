# redis

Redis from source, core only, a Containerfile on distroless'
`cc-debian13`: the binaries, linked against Debian trixie's libraries,
all of them distroless' packages. One image per release line
(`docker-bake.hcl`).
Runtime contract: the Containerfile's header. Upstream sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **A library distroless lacks** fails the final image's smoke test.
  Copy its package with its dpkg status, as
  `containers/haproxy/Containerfile` does.
- **What differs between lines** is a `case` on `BASE_VERSION`, the
  newest behaviour as its default, so a new line takes it: the
  compression build flag (from 8.10) and the license files. The smoke
  test reads the flags from `src/.make-settings`, not the version. The
  SPDX ids are the `LICENSES` argument of `docker-bake.hcl`.
- **Build with `make -C src`**: the top-level Makefile of 8.10 also
  builds and installs the bundled modules it finds.
- **Done when** the build passes: the build stage's server answers over
  TCP and TLS, with jemalloc's page size for the platform, a Sentinel
  reads its run ID, the final
  image runs `redis-cli` and `redis-check-rdb` on that server's dump,
  and `/bin/sh` is absent from it (`docker create`, then
  `docker export | tar -t`).

## Updates

Renovate moves each line within itself (`extractVersion`); patch
releases are automerged. The checksum is the tag's commit (tags are
lightweight): Renovate fills it in. Release notes: `00-RELEASENOTES` of
the tag.

- **Add a line** (a new minor release): copy a `base` entry in
  `docker-bake.hcl`, with its `# renovate:` comment (`depName`,
  `extractVersion` for that line), and the checksum from
  `git ls-remote https://github.com/redis/redis refs/tags/<version>`.
  Read the release's `src/Makefile` for new build flags, and its
  `LICENSE.txt`.
- **Drop a line** once `SECURITY.md` lists it unsupported: delete its
  entry; its tags stay in the registry. 7.4 is not built: RSALv2/SSPLv1
  only (REFERENCES.md).
- **6.2** has no `JEMALLOC_CONFIGURE_OPTS`: the jemalloc flags are a
  `sed` on `deps/Makefile`, checked by a `grep`. A line whose configure
  line changes fails there.
- **Debian 14**: a distroless digest update keeps trixie; moving changes
  both `FROM` lines.

## Deploying

- **Probes** exec `redis-cli ping`, with the password in
  `REDISCLI_AUTH` (an environment variable from the Secret), not `-a`:
  arguments show in the process list.
- **`/etc/redis` must be writable** for `CONFIG REWRITE` and Sentinel,
  which rewrites its config at start and fails on a read-only one. A
  ConfigMap or Secret mount is read-only: mount it elsewhere and copy it
  into an `emptyDir` at `/etc/redis` from an init container (this image
  has no shell: `containers/busybox`).
- **Sentinel:** `--entrypoint /usr/local/bin/redis-sentinel`, the config
  path as argument, port 26379 (not in `EXPOSE`).
- **Volumes** in Kubernetes: `fsGroup: 65532`, so the user writes
  `/data`.
- **The overcommit warning** in the log: `vm.overcommit_memory=1` is a
  node sysctl, not namespaced; the image can't set it.
