# almalinux

AlmaLinux bootc host, from
`quay.io/almalinuxorg/almalinux-bootc:<BASE_VERSION>`, 9 and 10 from
one Containerfile: `bootc/fedora`'s host system, same stages, plus
geo-blocking on the `public` zone. Sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Geo-blocking

Two firewalld policies on `public`, both `target=CONTINUE`: `geoblock`
(priority -10000) drops bogons and the countries listed in the
Containerfile's `geoblock` stage; `blocklist` (-9000) drops the threat
feeds' sources. The build-only `geoblock` stage fetches the data with
`ADD` and turns it into ipsets with `geoblock.nu` (nushell, its
`SHELL`).

- `geoblock.nu` is the only check of ipset entries: it fails the build
  on an invalid entry, an empty country, or a country overlapping a
  bogon. `test_geoblock.nu` tests it on every build; a change to one
  updates the other.
- Data refreshes only with a rebuild (weekly).
- Published ports (`-p`) bypass the policies: a reverse proxy runs with
  `network_mode: host`, backends on loopback, ACME by DNS-01.
- Kill switch: copy both policy files to `/etc/firewalld/policies/`,
  add `<disable/>` to each, `firewall-cmd --reload`.

## Platforms

`linux/amd64` is x86-64-v3; `linux/amd64/v2` (`x86_64_v2` RPMs, EPEL
from AlmaLinux's AltArch rebuild) is for older CPUs, chosen only by
`podman run --platform linux/amd64/v2`.

## Limits

On a v2 CPU, `bootc upgrade` fetches the v3 build, which won't boot
(pick the previous deployment in GRUB, or `bootc rollback`). Such hosts
need a tag pointing at the v2 build only.

## Updates

AlmaLinux 9 stays on 9: it is the image for x86-64-v2 hosts.
