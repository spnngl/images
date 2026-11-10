# fedora

Fedora bootc host, from `quay.io/fedora/fedora-bootc:<BASE_VERSION>`.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `sysroot/common/` and `policy.jq` are shared with almalinux: a change
  here changes it too. fedora-coreos has its own copies of
  `policy.jq` and the signature files (public key, `registries.d`): a
  key rotation updates both (`bootc/REFERENCES.md`, "Signing").
