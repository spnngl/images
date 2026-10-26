# numa-dns

Numa (DNS resolver with ad blocking, local zones, DNS-over-TLS and a
`.numa` reverse proxy; Rust) built from source, one static musl binary
on `scratch`. Upstream's image's paths (`/usr/local/bin/numa`,
`/var/lib/numa`, `/root/.config/numa/numa.toml`), so upstream's docs
apply; the image is named `numa-dns`, the binary `numa`. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `ENV HOME=/root` is what keeps every write in `/var/lib/numa`
  (upstream's `src/lib.rs`, `config_dir_unix`). Keep it while that
  function routes a `/root` home to the daemon directory.
- `CMD` names the config's path: numa then exits when it is missing,
  instead of serving its defaults, an open resolver.
- `numa.toml` is the image's config: DNS and DoT on every address for
  private networks (`allow_from`), DoT upstreams, API on loopback,
  `.numa` proxy and DoH off. An operator opens the others by mounting a
  config; the API, with `api_bind_addr = "0.0.0.0"`, stays guarded by
  the API token.
- `EXPOSE` lists every port numa can listen on, whatever `numa.toml`
  opens: a port numa adds goes there too.
- The build stage compiles and tests as UID 65532 (only packages and the
  musl target install as root): its cache ids end in `-65532`.
- The runtime contract holds for Kubernetes: a change to a path, port,
  listener or outbound connection updates it.

## Smoke tests

- Build stage, `smoke-test.toml`: `--version`, `/health`, a local zone
  over UDP and over DoT, an override added through the API and
  answered, and, with the image's `HOME`, a service saved in
  `/var/lib/numa`. Loopback only: no upstream, no blocklist.
- Final stage: `numa --version`, the static binary on this platform.

## Updates

Renovate follows upstream's GitHub tags. Minor and patch releases and
Rust bumps are automerged (the server test covers them); a major
release is never. Before merging one, read the release notes
(`https://github.com/razvandimescu/numa/releases/tag/v<new>`) for a
change to `numa.toml`'s keys, to the directories (`src/lib.rs`), or to
the `run` arguments: the server test reads its own config, not the
image's, and runs no `CMD`.
