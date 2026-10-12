# fedora

Fedora bootc host, from `quay.io/fedora/fedora-bootc:<BASE_VERSION>`.
Stages and build commands: the `Containerfile` header. Sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `sysroot/common/` and `policy.jq` are shared by every bootc image: a
  change here changes almalinux and centos too.
- Hostname, timezone, locale, NTP, DNS, sshd and services go in the
  image; `config.toml` holds only users.
- `usr/lib/bootc/install/50-rootfs.toml` keeps the root filesystem xfs.
- The pull secret `/etc/ostree/auth.json` (0640 root:wheel) stays
  machine-local; `usr/lib/tmpfiles.d/container-auth.conf` links root's
  `~/.docker/config.json` to it for podman and docker.
