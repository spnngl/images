# centos: references

## Sources

- Base image: <https://quay.io/repository/centos-bootc/centos-bootc?tab=tags>
- Shared bootc sources: `bootc/REFERENCES.md`

## Decisions

- **Custom Renovate manager for `BASE_VERSION`:** the dockerfile manager
  can't write a `stream<n>` tag back into the `ARG`.
- **`policy.json` in `/usr/share/containers`** (containers-common 6):
  the fallback when `/etc/containers/policy.json` doesn't exist.
- **subscription-manager's plugins off:** useless without a Red Hat
  subscription, and they write `/var/lib/rhsm` and `/run/rhsm` on every
  dnf run.
- **x86-64-v3 only:** the CentOS Stream 10 baseline; the base has no
  `v2` variant.
- **xfs:** the CentOS kernel has no btrfs (`CONFIG_BTRFS_FS` is not
  set), so EPEL's `btrfs-progs` can't mount one.
