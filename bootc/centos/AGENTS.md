# centos

CentOS Stream bootc host, from
`quay.io/centos-bootc/centos-bootc:stream<BASE_VERSION>`: `bootc/fedora`'s
host system with almalinux's packages, without geo-blocking. Docker from
Docker's CentOS repository. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

`BASE_VERSION` is the major release (`10`) and the image's tag; the base
tags it `stream10` (`FROM ...:stream${BASE_VERSION}`). A custom Renovate
manager updates the `ARG` and the matrix from `stream<n>` tags.
