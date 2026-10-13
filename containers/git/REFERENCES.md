# git: references

## Sources

- Upstream: `github.com/git/git`, tag `v<BASE_VERSION>`:
  `meson_options.txt` and `meson.build` (features, `https_backend`,
  `USE_CURL_FOR_IMAP_SEND`), `src/cargo-meson.sh` (Rust),
  `GIT-VERSION-GEN` (version), `ci/run-build-and-tests.sh` (the
  `linux-musl-meson` job), `imap-send.c` (`NO_OPENSSL`), `COPYING`
- OpenSSH: `github.com/openssh/openssh-portable`, tag
  `<OPENSSH_VERSION>` (`V_10_6_P1`): `README.md` (building from git),
  `configure.ac` (`use_pie`, `--disable-security-key`,
  `--disable-pkcs11`), `regress/test-exec.sh` (unprivileged `sshd`),
  `LICENCE`
- Alpine packages: <https://pkgs.alpinelinux.org/packages?branch=v3.24>
- Docs: <https://git-scm.com/docs>

## Decisions

- **A shell, against the rule of `containers/AGENTS.md`:** git runs
  `/bin/sh` for hooks, `!` aliases, credential helpers and its script
  commands (`git submodule`, `git mergetool`, `git filter-branch`), and
  execs a pager and an editor. `FROM` the busybox
  image gives all of them (`sh`, `less`, `vi`) and a passwd file; copying
  chosen applets into `scratch` would be the same binary with more
  lines.
- **Alpine build stage, not Debian:** libcurl must be static, with the
  libraries it links (OpenSSL, nghttp2, brotli, zstd, c-ares, libpsl,
  libidn2): Alpine ships each as a `*-static` package, Debian has no
  static libcurl. Its packages are not pinned (no snapshot: the branch
  keeps the newest build only), unlike the repository's Debian builds;
  the digest pins the branch, the weekly rebuild takes fixes.
  `BUILDKIT_SBOM_SCAN_STAGE` lists the stage's packages in the SBOM:
  static libraries leave no trace a scanner reads in a binary.
- **Not apko, nor Alpine's git package:** Renovate has no apko manager
  and apko is no buildx frontend; Alpine's git lags upstream (2.54 in
  3.24) and links dynamically.
- **Static, `-static-pie`:** busybox's image has no C library. musl
  links fully statically; `-static-pie` keeps ASLR. The build stage
  checks every ELF file it ships.
- **Meson,** as upstream's musl CI job: `prefer_static` asks pkg-config
  for static libraries; `--wrap-mode=nofallback` forbids downloads.
  `-Dversion` and `-Dbuilt_from_commit` replace `.git` (the source has
  none).
- **Rust on,** upstream's default. Its crate has no dependency, so no
  `cargo auditable` (nothing to list). Built in a copy of the source:
  cargo writes `Cargo.lock` beside `Cargo.toml`.
- **`https_backend=none`:** by default git links OpenSSL into every
  program, for `git imap-send`'s own TLS; with curl, `imap-send` uses
  libcurl instead. OpenSSL remains in the curl-based helpers
  (`git-remote-http`, `git-http-fetch`, `git-imap-send`).
- **Left out:** Perl and Python commands (`send-email`, `svn`, `p4`: no
  interpreter), gettext (English only), PCRE2 (`git grep -P`), expat
  (`git http-push`, WebDAV), gitk, git-gui, gitweb, contrib, man pages
  (`git help -a` works, `git help <command>` finds no page).
- **OpenSSH built, the client only:** git execs `ssh` for ssh:// and
  scp-like remotes; Alpine's `openssh-client` links dynamically.
  `--without-pie`: configure adds `-pie` after `--with-ldflags`, and the
  last wins: a dynamic `ssh`. Security keys and PKCS#11 load libraries
  at run time (dlopen): disabled. No `ssh-keygen` or `ssh-agent`: keys
  come from the runtime. From git, not a release tarball: Renovate
  follows the tag and Bake checks its commit, as for git; hence
  autoreconf (with automake's aclocal).
- **Transport tests in the build stage:** the image has neither `sshd`
  nor a TLS server. `sshd` runs as 65532, as OpenSSH's regress tests run
  it (`StrictModes no`, its own session and auth binaries), without a
  sandbox (`--with-sandbox=no`, which builds `sshd-auth` only): QEMU,
  building the other platform on a workstation, refuses seccomp, and
  configure rejects rlimit's on Linux. HTTPS is
  git's dumb protocol from `openssl s_server -WWW`: it tests libcurl,
  OpenSSL and certificate checks, the parts static linking risks; smart
  HTTP would need a CGI server for `git-http-backend`.
- **CA bundle:** Alpine's `ca-certificates-bundle`, at libcurl's
  default path (`curl-config --ca`, checked in the build stage).
- **Entrypoint `/usr/bin/git`, `CMD ["--version"]`,** working directory
  `/git`: `docker run <image> clone <url>`. A repository owned by
  another UID needs `safe.directory`.
- **UID 65532, busybox's nonroot (`HOME` `/tmp`):** `ssh` refuses a UID
  without a passwd entry, and writes `known_hosts` under `HOME`.
- **Automerge:** the smoke test builds both and runs both transports.
- **Licenses:** git `GPL-2.0-only` (parts `LGPL-2.1`, `COPYING`),
  OpenSSH `SSH-OpenSSH`, both in `/usr/share/doc/`. The static
  libraries' (curl, OpenSSL `Apache-2.0`, zlib, nghttp2, brotli, zstd,
  c-ares, libpsl, libidn2, libunistring) are in the SBOM's packages,
  not in the image: Alpine's packages ship no license file.
