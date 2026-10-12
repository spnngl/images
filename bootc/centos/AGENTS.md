# centos

CentOS Stream bootc host, from
`quay.io/centos-bootc/centos-bootc:stream<BASE_VERSION>`: `bootc/fedora`'s
host system with almalinux's packages (EPEL from CentOS'
`extras-common`), without geo-blocking. Docker from Docker's CentOS
repository. Same stages as `bootc/fedora`. Upstream sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `BASE_VERSION` is the major release (`10`) and the image's tag; the
  base tags it `stream10` (`FROM ...:stream${BASE_VERSION}`). A custom
  Renovate manager updates the `ARG` and the matrix from `stream<n>`
  tags.
- The base's `policy.json` is `/usr/share/containers/policy.json`; ours
  goes to `/etc` and is checked against it.
- subscription-manager's dnf plugins (`subscription-manager`,
  `product-id`) are disabled.
- amd64 is x86-64-v3 only; older CPUs use `almalinux:9`.
