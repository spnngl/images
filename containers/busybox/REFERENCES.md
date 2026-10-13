# busybox: references

## Sources

- Upstream: `git.busybox.net/busybox`, mirrored by its maintainer at
  `github.com/vda-linux/busybox_mirror`, tag `<BASE_VERSION>` with
  underscores (`1_38_0`): `INSTALL` (build and install), `Config.in`
  (`STATIC`, `INSTALL_APPLET_SYMLINKS`, `FEATURE_VERSION`), `Makefile`
  (`defconfig`, `KBUILD_DEFCONFIG`, version), `scripts/kconfig/Makefile`
  and `scripts/kconfig/confdata.c` (configuration files),
  `Makefile.custom` and `applets/install.sh` (`make install`),
  `networking/wget.c` (`FEATURE_WGET_HTTPS`), `testsuite/` (`make check`)
- Docs and release notes: <https://busybox.net>

## Decisions

- **A shell, against the rule of `containers/AGENTS.md`:** the image is
  a toolbox (debugging a pod, an init container's `sh -c`, a binary to
  `COPY --from`), useless without its shell and applets. Every other
  image stays shell-less; none is built `FROM` this one.
- **Static, musl:** scratch has no C library, and `COPY --from` puts the
  binary in images with none or another. musl links fully statically;
  glibc's static binaries still load NSS modules at run time. Debian's `musl-tools` (`musl-gcc`), from the
  snapshot, as `containers/garage` builds its C libraries; `debian:
  trixie-slim`, as busybox needs no other toolchain.
- **No `debian` matrix:** the image has no Debian file and uses none at
  run time; Debian 13 only builds it (`apt_args("13")`).
- **Kernel headers linked into musl's include folder:** `musl-gcc`
  searches musl's headers only, and busybox includes `linux/`, `asm/`
  (with `asm-generic/`) and `mtd/` from `linux-libc-dev`. Not all of
  `/usr/include`: glibc's headers would mix in.
- **Configuration: `defconfig` plus `static_defconfig`,** through the
  Makefile's `KBUILD_DEFCONFIG`: upstream's general-purpose set
  (`INSTALL`), each change in one file with its reason. Disabled: what
  doesn't build against musl and current kernel headers, today `tc`
  (its CBQ definitions are gone from trixie's `linux-libc-dev`). Applets
  that build but do little in a container (`linuxrc`, module tools)
  stay: `defconfig`'s set.
- **Version:** the Makefile's (`VERSION`, `PATCHLEVEL`, `SUBLEVEL`);
  `busybox --version` prints it with `SOURCE_DATE_EPOCH`'s date, so a
  rebuild of one commit is the same binary.
- **Built in a copy of the source:** configuring writes into the source
  tree, even out of tree (`.kernelrelease`, `bb_libtest.c`), and the
  source stays root's.
- **Renovate:** the tag (`1_38_0`) is the written version, read by a
  regex versioning in the `# renovate:` comment; Bake makes it dotted
  for `BASE_VERSION` and the tag, and the Containerfile back to
  underscores for `ADD` (`${BASE_VERSION//./_}`, Dockerfile syntax
  1.10+): `extractVersion` can't rewrite `_` to `.`.
- **Smoke test, not upstream's testsuite:** in a build container, as
  65532, `make check` fails 34 of its 1042 cases, the build being fine
  (mdev, taskset: root or capabilities; date-timezone, `ls -q`/`-Q`, sed
  and awk cases, cpio, tar, unzip): a skip list to keep per release.
- **No automerge:** the smoke test covers a few applets; a release
  changes many.
- **UID 65532:** the repository's default, enough for most applets.
  Those that need root (mount, network changes, nsenter) get `--user 0`
  and their capabilities, explicitly.
- **No `ENTRYPOINT`, `CMD ["/bin/sh"]`:** as Docker's `busybox` image:
  `docker run <image> ls /` and Kubernetes' `command:` run any applet or
  path; an entrypoint `/bin/busybox` would also run applets, but not a
  program an image built from this one adds.
- **`/tmp`, `1777`:** the shell and its tools (`mktemp`, `sort`) write
  there; scratch has none.
- **No CA bundle:** busybox's TLS (`wget https://`) checks no
  certificate (`networking/wget.c`, `FEATURE_WGET_HTTPS`): a bundle
  would suggest it does.
- **A passwd and a group file (root, nonroot 65532, nobody/nogroup),
  no password:** names for `id`, `whoami`, `ls -l` and the prompt, as
  Docker's `busybox` image; the runtime sets `HOME` from them:
  `/tmp` for nonroot, the one folder it can write (shell history),
  `/root` (0700) for root. Credentials still come from the runtime: `*`
  locks every password, and there is no shadow file.
- **`/usr/share/doc/busybox/`:** `LICENSE` (GPL-2.0-only) and `config`,
  the build's `.config`: with upstream's tag, the source the GPL asks
  for.
