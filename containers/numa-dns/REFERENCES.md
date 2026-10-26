# numa-dns: references

## Sources

- Upstream: `github.com/razvandimescu/numa` at tag `v<BASE_VERSION>`:
  `.github/workflows/release.yml` (release build), `Dockerfile`
  (upstream's image), `numa.toml` (every key, with its default),
  `src/config.rs` (defaults, config lookup), `src/lib.rs` (directories),
  `src/system_dns.rs` (`/etc/resolv.conf`'s search domains),
  `src/api_auth.rs` (API token), `build.rs` (version)
- Docs: `README.md` (Docker), `recipes/network-wide.md` (serving a LAN)

## Decisions

- **Containerfile on `scratch`, static musl:** upstream releases a
  static musl binary (`release.yml`). Numa execs `hostname` and
  `resolvectl` only as fallbacks (`src/lib.rs`, `src/system_dns.rs`):
  without them, `/health` reports the hostname `numa` and system DNS
  comes from `/etc/resolv.conf`.
- **`rust:<version>-trixie`, musl target:** `musl-gcc` (`musl-tools`)
  builds the C the crates bundle (ring, mimalloc). Default features and
  Cargo.toml's release profile, as `release.yml` builds.
- **Version from Cargo.toml:** the source has no `.git`, so `build.rs`'s
  `git describe` yields nothing and `--version` prints the package
  version, the tag's.
- **Built and tested as UID 65532:** the crates' build scripts and the
  test server run without root and can't change the source (root's).
  A cache keeps the owner it was created with: hence ids of their own.
- **`cargo auditable`** embeds the crate list in the binary: without
  it, the SBOM and the scans see no Rust dependency.
- **Server test in the build stage:** `scratch` has no shell to run a
  server in the background. `dig` (`bind9-dnsutils`) queries it over UDP
  and DoT, so the test covers resolution, the minted CA and rustls.
- **Not root, unlike upstream:** numa needs no privilege beyond its
  ports, and a pod passes the `restricted` Pod Security Standard. Ports
  53 and 853 kept, upstream's and clients': Docker's bridge network and
  containerd 2 let any user bind under 1024, and
  `net.ipv4.ip_unprivileged_port_start` is a safe sysctl elsewhere.
- **Probe on TCP 53:** the kubelet reaches the pod's address, not its
  loopback, where the API and `/health` stay. numa accepts a connection
  before `allow_from` drops it, so the probe passes from any address.
- **`HOME=/root`:** `config_dir_unix` (`src/lib.rs`) puts services and
  lists under `$HOME/.config/numa`, unless the home is under `/root`:
  then under `/var/lib/numa`, with the CA, token and blocklists, as in
  upstream's root image. numa's commands (`numa token`) then find
  `/root/.config/numa/numa.toml`, upstream's documented path. Docker's `HOME=/` would point saves at the read-only
  `/.config/numa`: a warning each, the services and lists lost at
  restart.
- **The image's config, over upstream image's** (API and proxy on
  `0.0.0.0`, numa's defaults otherwise):
  - DNS and DoT on every address, the resolver the container serves,
    for private networks only (`allow_from`): without it, a published
    port 53 makes an open resolver (upstream's `numa.toml`).
  - API and dashboard on loopback: what changes resolution stays inside
    the container until an operator opens it.
  - Proxy off: it holds DoH too, and on loopback (numa's default) no
    client reaches either.
  - DoT upstreams by IP literal (Cloudflare, Google), DoH by IP as
    fallback: queries leave encrypted, with no lookup of a resolver's
    name. Not the network's resolver, numa's default.
  - Blocklist numa's default, hagezi pro: about 210,000 domains, 20 MiB
    of memory at 0.25.0. Chosen over hagezi ultimate and TIF (2.3
    million domains, 180 MiB).
- **`EXPOSE` every port numa can listen on:** it documents, and `-P`
  publishes them; a config decides which listen beyond loopback.
- **No CA bundle:** numa checks upstreams (DoH, DoT, ODoH) and blocklist
  downloads against Mozilla's roots compiled in (`webpki-root-certs`,
  `numa_tls_builder` in `src/forward.rs`), never the system's. They
  refresh with numa's releases.
- **Entrypoint `/usr/local/bin/numa`, `CMD ["run",
  "/root/.config/numa/numa.toml"]`:** a named config must exist
  (`named_config_path`, `src/config.rs`), so a ConfigMap without
  `numa.toml` stops numa. Bare `run` searches `/var/lib/numa` first,
  then falls back to numa's defaults: DNS on `0.0.0.0:53` for every
  client. `docker exec <container> /usr/local/bin/numa token` prints the
  API token, as upstream's docs do with `numa token`.
- **No `HEALTHCHECK`:** no curl in the image, and Kubernetes ignores it.
