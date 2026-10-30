# zot: references

## Sources

- Upstream: `github.com/project-zot/zot` at tag `v<BASE_VERSION>`:
  `Makefile` (`binary` and `ui` targets, `ZUI_VERSION`),
  `build/stacker.yaml` (release build and image, run by
  `.github/workflows/publish.yaml`; its config), `build/Dockerfile`
  (`/usr/bin/zot`, `HEALTHCHECK`), `pkg/cli/server` (subcommands,
  healthcheck), `pkg/api/config/config.go` (`UpdateReloadableConfig`:
  what a config change reloads)
- Web UI: `github.com/project-zot/zui` at the tag zot's `Makefile`
  names: `.github/workflows/build-test.yml` (release build),
  `vite.config.js` (output folder)
- Docs: `https://zotregistry.dev/`

## Decisions

- **Full build:** `make binary`'s default extensions, as upstream's
  `zot` image; no `zot-minimal`.
- **UI built from source:** without `ZUI_BUILD_PATH`, the `Makefile`
  downloads zui's release tarball unchecked. The version comes from
  zot's `Makefile`, checked by the build. zui's tags (`commit-<hash>`)
  have no order: `versioning=git` makes the pinned tag an invalid
  version, so Renovate updates only its commit (as for a branch). The
  default, semver-coerced, would read `commit-8e8457d` as `8.0.0`.
- **`npm ci --ignore-scripts`:** the lockfile's versions and hashes;
  esbuild's install script only checks its binary, fsevents' is
  macOS-only. The npm packages reach the SBOM through a scan stage, as
  `containers/cinny`.
- **Commits pinned** (`ADD --checksum`): tags can be moved. No `.git`:
  the `Makefile` reads the commit with git only when `COMMIT` is unset;
  it is given upstream's release value, `v<version>-<commit>`.
- **`BUILDMODE_FLAGS` emptied:** a Go PIE asks for a dynamic loader,
  which `scratch` lacks (`containers/miniflux`). The test checks
  `-buildmode=exe` and `CGO_ENABLED=0`.
- **Built and tested as UID 65532:** upstream code runs in the build
  (npm, make, the server), and the test runs zot as the image does. The
  `Makefile` writes into the source, hence the user's own copy. A
  root-owned binary can't be rewritten by zot.
- **Server test in the build stage:** Renovate automerges zot minor and
  patch releases and `golang` bumps; `scratch` has no shell. CVE
  scanning is left out: it downloads Trivy's databases from `ghcr.io`.
  The test starts on empty storage: it doesn't open the metadata
  (`cache.db`, `meta.db`) of an older release.
- **Default config:** upstream's, but log level `info`, not `debug`, and
  no `mgmt`: zot ignores it, with a warning (`pkg/cli/server/root.go`).
  No auth: credentials come from the runtime (`containers/AGENTS.md`),
  through a mounted config.
- **`HEALTHCHECK`:** `build/Dockerfile`'s; `zot healthcheck` reads the
  config's address and port, so it follows a mounted config.
- **The image holds the binary, Debian's CA bundle** (sync, Trivy's
  databases, OpenID, LDAP, cloud storage), the config, `/tmp` (Trivy,
  through `os.TempDir`), `/var/lib/registry` owned by 65532, and the
  licenses: zot's `LICENSE`, `NOTICE`, `THIRD-PARTY-LICENSES.md`, and
  zui's `LICENSE`. Not distroless (upstream's base): its extras are
  unused by zot. An AWS `credential_process` (sync's ECR helper) runs
  through `sh`, which `scratch` lacks: give AWS credentials another way.
- **Binary at `/usr/bin/zot`:** `build/Dockerfile`'s path.
