# angos: references

## Sources

- Upstream: `github.com/project-angos/angos` at tag `v<BASE_VERSION>`:
  `.github/workflows/build.yaml` (release binaries: target, `RUSTFLAGS`,
  Node version; e2e runs of the image), `Dockerfile` (upstream's image),
  `build.rs` (UI build), `src/main.rs` (commands, `-c`, SIGTERM),
  `src/command/server/router/mod.rs` (`/healthz`, `/readyz`, UI routes),
  `src/command/server/handlers.rs` (embedded UI, `ui/build`),
  `src/command/scanner/tool.rs` (trivy and grype, run from `PATH`),
  `src/identity/action/mod.rs` (the actions an access policy sees, the
  probes' and the UI's included)
- Docs: `doc/` at the tag: `how-to/deploy-docker-compose.md` and
  `deploy-kubernetes.md` (paths, arguments, probes, credentials in a
  second file), `how-to/set-up-access-control.md` (open probes),
  `how-to/scan-images.md`, `how-to/upgrade.md`,
  `reference/configuration.md`

## Decisions

- **`rust:<version>-trixie`, musl target:** upstream's release
  binaries are musl builds; `musl-gcc` (`musl-tools`) builds the C code
  (aws-lc, ring). `--locked`: `Cargo.lock`'s versions. Not upstream's
  `RUSTFLAGS` (`-Clinker=rust-lld`): they serve its cross builds, and
  `rust-lld` rejects the `-Wl,` flag cargo auditable adds.
- **Node from `node:<version>-trixie-slim`, in the Rust stage:**
  `build.rs` runs npm whenever `ui/` exists, and the binary embeds
  `ui/build` (rust-embed), so Node must be where cargo runs. Only `node`
  and npm are copied: the binary links glibc and libstdc++, both in
  Rust's image. `npm ci` first: `package-lock.json`'s versions and
  hashes, where `build.rs` would run `npm install`.
- **`cargo auditable`** embeds the crate list in the binary: without
  it, the SBOM and the scans see no Rust dependency.
- **UI packages in the SBOM** (`BUILDKIT_SBOM_SCAN_STAGE` on
  `angos-files`): the bundle names no package. All of `node_modules`,
  build tools included: some (svelte, `@sveltejs/kit`) are in the
  bundle.
- **Built and tested as UID 65532**, in its own copy of the source
  (`build.rs` writes `ui/`): install scripts, build scripts and the
  test server run without root. A cache keeps the owner it was created
  with: hence ids of their own.
- **Server test in the build stage:** `scratch` has no shell, and the
  binary has no `--version`. The password is hashed with Debian's
  `argon2`, as `angos argon` does (argon2id, 19 MiB, 2 passes): that
  command reads the password from a terminal. The final stage runs
  `--help`, which exits 0.
- **UID 65532, not upstream's 65534:** the repository's user
  (`containers/AGENTS.md`); every port is above 1024.
- **`CMD ["-c", "/config/config.toml", "server"]`**, where upstream has
  none: every upstream guide passes these arguments, so its compose
  `command:` and Kubernetes `args:` replace them as is.
- **`/data` owned by 65532, no `VOLUME`:** upstream's guides put
  `[blob_store.fs]` there; an S3 store writes nothing locally, and a
  `VOLUME` would give each container an anonymous volume.
- **Debian's CA bundle**, as upstream's image: TLS to S3, upstream
  registries, OIDC issuers, webhooks.
- **No config in the image:** storage, identities and policies are the
  deployment's.
- **No scanner in the image:** upstream mounts the trivy or grype image
  and sets `PATH` (`how-to/scan-images.md`); `scanner` mode runs from
  this image the same way.
- **`RUST_LOG` unset**, as upstream's image: errors only by default.
- **Never automerged:** upstream's patch releases carry breaking
  changes (`how-to/upgrade.md`, 1.12.1, 1.12.3).
- **No `HEALTHCHECK`:** no curl in the image, and Kubernetes ignores it.
