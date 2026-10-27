# fedora: references

## Sources

- Base image: <https://quay.io/repository/fedora/fedora-bootc?tab=tags>
- Shared bootc sources: `bootc/REFERENCES.md`

## Decisions

- **`50-rootfs.toml` sets `xfs`:** the Fedora base sets no default,
  so `bootc install to-disk` and image-builder would each need a
  filesystem flag. xfs works on every image: the CentOS kernel has no
  btrfs.
- **System config in the image:** bootc disk images don't accept
  hostname, timezone, locale, NTP, DNS or services from the blueprint.
- **Pull secret outside the image:** it is machine-local, added to the
  disk image by `config.toml` if wanted. One file serves bootc, podman
  and docker.
- **sshd on 42022 only**, so the firewall opens 42022 (and 80, 443)
  and drops `ssh` (22); `cockpit` isn't installed.
- **Key-only root login in the image, off after install by a drop-in**
  (`etc/ssh/sshd_config.d/10-myssh.conf`): `bootc install
  to-existing-root` leaves root as the only user, so the first login
  needs it. sshd keeps the first value of a keyword (sshd_config(5)),
  so `05-after-install.conf` overrides the image's file without
  editing it: an edited `/etc` file no longer takes the image's changes
  (`ostree admin config-diff` lists it as `M`).
- **Fedora releases from endoflife.date in Renovate:** the image's tags
  name the branched release and rawhide by number before release.
