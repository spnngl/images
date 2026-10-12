# almalinux: references

## Sources

- Base image: <https://quay.io/repository/almalinuxorg/almalinux-bootc?tab=tags>
- Country zones: <https://www.ipdeny.com/ipblocks/>
- nushell, the `geoblock` stage's shell: `github.com/nushell/nushell` at
  that image's tag
- Shared bootc sources and firewalld's: `bootc/REFERENCES.md`

## Decisions

- **Policies, not zone rules, with `target=CONTINUE`:** traffic not
  dropped still goes through the `public` zone's rules unchanged.
- **IPv4 only:** IPv6 is disabled on every image.
- **Baked in, not fetched at runtime; `ADD`, not `RUN curl`:** `ADD`
  keys its cache on the content's digest, so a build reruns only what
  changed. Nothing from the stage but the ipsets and the source data
  reaches the image; the source data (`/usr/share/geoblock/`) traces a
  blocked IP to its country or feed.
- **Compacted ipsets:** ipdeny's zones aren't aggregated and the feeds
  overlap; networks merge into the fewest covering the same addresses.
  Feed entries inside a blocked country are dropped: `blocklist` never
  sees that traffic.
- **Fail closed, so validate:** corrupt country data blocks legitimate
  traffic, possibly the admin's; `firewall-offline-cmd --check-config`
  doesn't check ipset entries (`bootc/REFERENCES.md`, "Firewalld").
  `0.0.0.0/0` in a country would overlap a bogon range.
- **Countries are by address registration:** the US zone covers the
  European regions of US clouds (AWS, GCP, Azure), Cloudflare and
  GitHub. Blocking it drops their inbound traffic (webhooks,
  monitoring, proxied requests); outbound connections still work.
- **Host-network reverse proxy:** Docker DNATs published ports before
  firewalld's policies run. Let's Encrypt validates HTTP-01 from
  several regions, hence DNS-01.
- **Two x86_64 builds:** AlmaLinux 10's baseline is x86-64-v3, and its
  glibc aborts with `CPU does not support x86-64-v3` on older CPUs.
  containers/image (podman, bootc) doesn't detect x86-64 levels: on
  amd64 it picks the entry without a variant. bootc has no platform
  option.
