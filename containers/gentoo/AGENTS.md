# gentoo

Gentoo's stage3, one flavor per tag (`musl-hardened`: OpenRC;
`musl-hardened-systemd`): a build environment for CI jobs that compile
Gentoo packages. Runtime contract:
the Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **The final image is the stage3's files alone, times included**
  (`rewrite-timestamp=false`, REFERENCES.md). What a job needs
  beyond them (ebuild repository, `make.conf`) is the job's.
- **Every signature matches the pinned fingerprint** of Gentoo's release
  key, the latest file's before its path is used.
- **The final stage's `RUN` is exec form, with no `SHELL`:** images built
  on this one inherit the stage's shell.
- **Done when** the build passes (the final stage's smoke test runs
  portage and a program gcc built) and `docker run <image> whoami`
  prints `root`.

## Updates

Each build takes Gentoo's latest stage3; the weekly rebuild, a newer
one. A new flavor: an entry of `docker-bake.hcl`'s matrix, its tag
the flavor, OpenRC's without `-openrc`.

A build failing on the key check means Gentoo changed its release key.
Confirm the new fingerprint on <https://www.gentoo.org/downloads/signatures/>
(*Gentoo Linux Release Engineering (Automated Weekly Release Key)*),
then replace `key=` in the Containerfile.
