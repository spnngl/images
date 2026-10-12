# garage: references

## Sources

- Upstream: `git.deuxfleurs.fr/Deuxfleurs/garage` at tag
  `v<BASE_VERSION>`: `doc/book` (docs), `nix/compile.nix` (release
  build)
- Docs: <https://garagehq.deuxfleurs.fr/documentation/>, multi-node:
  <https://garagehq.deuxfleurs.fr/documentation/cookbook/real-world/>

## Decisions

- **`rust:<version>-trixie`, musl target:** rustup's musl targets link
  statically by default; `musl-gcc` (`musl-tools`) builds the C
  libraries the crates bundle (libsodium, LMDB, SQLite, zstd, ring),
  `protobuf-compiler` the OTLP exporter's protobufs. `GIT_VERSION` sets
  what `--version` prints (the source has no `.git`).
- **Built and tested as UID 65532:** the crates' build scripts and the
  test server run without root and can't change the source (root's).
  `CARGO_HOME` and `RUSTUP_HOME` are set, so cargo needs no `HOME`.
  A cache keeps the owner it was created with: hence ids of their own.
- **`cargo auditable`** embeds the crate list in the binary: without
  it, the SBOM and the scans see no Rust dependency.
- **Server test in the build stage:** Garage has no side-effect-free
  config check, and `scratch` has no shell to run a server in the
  background.
- **Entrypoint `/garage`**, where upstream only has `CMD ["/garage",
  "server"]`: Kubernetes' `command:` replaces it anyway (upstream's
  chart sets none or `["/garage"]`), and `docker exec <container>
  /garage status` is unchanged.
- **Not root, unlike upstream:** every port is above 1024. The state
  folders are 65532's in the image, so a new named volume is writable; a
  bind mount needs that owner. Garage refuses a secret file readable by
  others.
- **Debian's CA bundle**, for TLS to Consul, Kubernetes or an OTLP
  collector; upstream's image has none.
- **No config in the image:** it is the cluster's
  (`replication_factor`, `rpc_public_addr`, ...).
- **No `HEALTHCHECK`:** no curl in the image, and Kubernetes ignores it.
