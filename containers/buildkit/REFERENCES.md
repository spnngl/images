# buildkit: references

## Sources

- Upstream: `github.com/moby/buildkit`, tag `v<BASE_VERSION>`:
  `Dockerfile` (the `buildkitd`, `buildctl`, `runc`, `rootlesskit` and
  `rootless` stages, `RUNC_VERSION`, `ROOTLESSKIT_VERSION`),
  `docs/rootless.md`, `examples/kubernetes/deployment+service.rootless.yaml`,
  `cmd/buildkitd/main.go` (`isRootlessConfig`),
  `util/appdefaults/appdefaults_unix.go` (state, socket and
  configuration paths), `util/gitutil/git_cli.go` and
  `source/git/source.go` (git, submodules), `executor/oci/spec.go`
  (`WithNewPrivileges`), `LICENSE`
- runc: `github.com/opencontainers/runc`, tag `v<RUNC_VERSION>`:
  `Makefile` (`static`, `BUILDTAGS`, `COMMIT`), `README.md` (libpathrs),
  `CHANGELOG.md` (libpathrs required from 1.6)
- RootlessKit: `github.com/rootless-containers/rootlesskit`, tag
  `v<ROOTLESSKIT_VERSION>`: `cmd/rootlesskit`, `pkg/parent/parent.go`
  (`newuidmap`, `/etc/subuid`)
- shadow: `github.com/shadow-maint/shadow`, tag `<SHADOW_VERSION>`:
  `lib/idmapping.c` (`write_mapping`, capabilities), `src/newuidmap.c`,
  `src/Makefile.am` (`LIBCAP`, `suidperms`), `configure.ac`
- User namespaces: `user_namespaces(7)` (who may write an id map)
- Alpine packages: <https://pkgs.alpinelinux.org/packages?branch=v3.24>

## Decisions

- **A shell, against the rule of `containers/AGENTS.md`:** buildkitd
  runs `git` for git sources, and `git submodule` is a `#!/bin/sh`
  script; BuildKit's own image has Alpine's shell too. `FROM` the git
  image gives git, a shell, ssh and a passwd file; copying them into
  `scratch` would be the same files with more lines.
- **Rootless only:** the rootful image needs a privileged container;
  this one runs as 65532 under RootlessKit, the way Kubernetes runs
  build pods (`docs/rootless.md`).
- **Built here, not copied from `moby/buildkit`:** the repository builds
  its images from source (`ARCHITECTURE.md`), pinned by tag and commit.
  The flags are upstream's Dockerfile: buildkitd `osusergo netgo
  static_build seccomp` and `-X version.{Version,Revision,Package}`;
  runc with cgo, linked statically; RootlessKit CGO off.
- **runc without libpathrs:** runc 1.5 enables it by default (a Rust
  library) and 1.6 requires it; BuildKit's Dockerfile builds without.
  Every `RUN` here is unprivileged, in a user namespace.
  A runc update to 1.6 fails the build: building libpathrs is then the
  decision to make.
- **Own pins for runc, RootlessKit and shadow:** BuildKit's Dockerfile
  pins runc and RootlessKit, but Renovate can't read a Dockerfile `ARG`
  from another repository; each is a bake entry, as git's OpenSSH.
  RootlessKit is 3.3.0, upstream's is 3.2.0: nothing in BuildKit's code
  needs the older one, and the smoke test runs it.
- **shadow from source:** `newuidmap` and `newgidmap` are the only helpers
  RootlessKit needs. Alpine's shadow-uidmap links dynamically and uses
  file capabilities (an xattr `COPY` may drop), Debian's 4.17 is old.
  Built from git (`autoreconf`), `--disable-shared`, libtool's
  `-all-static` at make time (`LDFLAGS=-static` at configure is dropped).
- **setuid, with libcap:** the kernel lets the writer of
  `/proc/<pid>/uid_map` do it only with `CAP_SYS_ADMIN` over that
  namespace, or the namespace owner's UID. A setuid-root `newuidmap`
  has root's UID and a container's capabilities, without
  `CAP_SYS_ADMIN`: "write to uid_map failed: Operation not permitted".
  shadow 4.19+ takes the caller's UID back (`seteuid`) while holding
  `CAP_SETUID`, when built with libcap. configure doesn't look for
  libcap: `LIBCAP=-lcap` links it. Found by running the helper in
  `moby/buildkit:rootless`'s place.
- **UID 65532, `/etc/subuid` `65532:100000:65536`:** the git image's
  nonroot; `newuidmap` finds a user's range by name or number, 65532 has
  an entry in busybox's passwd. 100000 and 65536: what BuildKit's image
  and Debian's `useradd` give.
- **`USER=nonroot` and `XDG_*` in the environment, no `--root`:**
  buildkitd treats itself as rootless only when `$USER` is set and not
  root (`isRootlessConfig`); only then are its defaults the user's, from
  `XDG_DATA_HOME` (`/var/lib/buildkit`), `XDG_CONFIG_HOME`
  (`/etc/buildkit/buildkitd.toml`) and `XDG_RUNTIME_DIR` (the socket).
  A replaced `CMD` keeps them, flags don't.
- **`CMD ["--oci-worker-no-process-sandbox"]`:** Kubernetes can't set
  `systempaths=unconfined`, which the process sandbox needs
  (`docs/rootless.md`); in a container the pod is the sandbox. No
  network address by default: one is root-equivalent and BuildKit's
  example uses TLS; the header gives the arguments. The
  working directory and `VOLUME` are the state, `/var/lib/buildkit`.
- **No `unpigz`, no `fuse-overlayfs`, no CNI, no QEMU binaries:** BuildKit
  falls back (gzip in Go; `overlayfs` as 5.11+ kernels allow, else
  `native`); CNI is for rootful networking, rootless is always host.
  Added when someone needs them.
- **The daemon test in the final stage:** it tests what ships (setuid
  helpers, ranges, git). It needs `security.insecure`: a build container
  has no user namespace permission, the daemon creates one. It builds
  from a git source because that is the path through `git` and the shell,
  and runs a `RUN` as root and as UID 1000: BuildKit clears
  `no_new_privs` for every `RUN` (`WithNewPrivileges`), so setuid works in
  builds. It can't test the helper's setuid bit: the insecure `RUN` has
  more capabilities than the container; the checks are by hand.
  `/tmp` is a tmpfs: no state in a layer.
- **Automerge:** the test builds an image with every part, but not the
  runtime's seccomp and AppArmor; a rootless regression in a kernel
  shows only at run time.
- **Licenses:** BuildKit, runc and RootlessKit `Apache-2.0`, shadow
  `BSD-3-Clause`, in `/usr/share/doc/`; git, OpenSSH and busybox come
  with the base image. libseccomp (`LGPL-2.1-only`) and libcap are linked
  statically: in the SBOM's packages, not in the image.
