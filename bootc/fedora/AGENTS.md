# fedora

Fedora bootc host, from `quay.io/fedora/fedora-bootc:<BASE_VERSION>`.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `sysroot/common/` and `policy.jq` are shared by every bootc image: a
  change here changes almalinux and centos too, and fedora-coreos for
  `policy.jq` and the signature files (public key, `registries.d`).
