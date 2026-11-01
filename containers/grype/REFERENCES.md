# grype: references

## Sources

- Upstream: `github.com/anchore/grype` at tag `v<BASE_VERSION>`:
  `.goreleaser.yaml` (`builds[linux-build]`: release build, flags,
  ldflags), `cmd/grype/main.go` (version variables), `Dockerfile` and
  `Dockerfile.nonroot` (upstream's images),
  `grype/db/v6/installation/curator.go` (database location and schema
  folder), `cmd/grype/cli/options/database.go` (database settings),
  `cmd/grype/cli/commands/root.go` (`checkForAppUpdate`)
- `github.com/adrg/xdg` (`XDG_CACHE_HOME`, and its fallback to `/` without
  `HOME`), `github.com/anchore/go-homedir` (`Dir` runs `getent` or `sh`
  without `HOME`, only when a path starts with `~`)

## Decisions

- **Static binary on scratch:** `CGO_ENABLED=0`, SQLite is pure Go
  (`glebarez/sqlite`). The only program grype runs, `xz` or `zstd`
  (`grype/db/internal/tarutil/writer.go`), packages databases for
  database builders, never a scan.
- **Upstream's release build, plus `-trimpath`:** the tags
  `containers_image_openpgp,exclude_graphdriver_btrfs` and `-w -s`;
  `-extldflags '-static'` left out (a no-op without cgo); `-trimpath` so
  the binary holds no build path. The four version variables are set as
  goreleaser sets them, from `BASE_VERSION`, `BASE_CHECKSUM` and
  `SOURCE_DATE_EPOCH`, so the source is added without `.git`.
- **`XDG_CACHE_HOME=/cache`, `VOLUME /cache`:** the database (about 200
  MB compressed) is downloaded at the first scan, and a persistent volume keeps it
  across runs: Kubernetes' PVC, or an `emptyDir` shared with the init
  container. Without `HOME` (no passwd entry) the default falls to
  `/.cache`, closed to 65532. `XDG_CACHE_HOME` over `GRYPE_DB_CACHE_DIR`:
  the database is the only cache grype keeps today, and the XDG variable
  also moves any a dependency adds.
- **`GRYPE_CHECK_FOR_APP_UPDATE=false`:** the check calls Anchore at
  every start and only logs; the image's tag is the version.
- **`/tmp`, mode 0777:** grype unpacks the scanned image's layers there
  (stereoscope), and upstream's `WORKDIR /tmp` creates it. The mode is
  explicit because Docker mounts a tmpfs with the image folder's mode, and
  a 0755 one is closed to 65532 (`permission denied` on
  `/tmp/stereoscope-*`). Kubernetes' `emptyDir` is world-writable anyway.
- **User 65532, not root:** registries and archives need no privilege;
  upstream's `Dockerfile.nonroot` runs non-root too. The Docker socket
  (root or its group) is out of scope.
- **Real scan as smoke test, per platform:** the build downloads the
  database (~75 s) and scans `pkg:maven/.../log4j-core@2.14.1` from a
  `purl:` file: the smallest input that exercises the database, the
  Java matcher and `--fail-on`. A purl rather than an SBOM: one line
  instead of a JSON document. `CVE-2021-44228` is the report's proof; the
  scan must fail on `high`.
- **Automerge, patch and minor:** the real scan covers a release.
  Grype is 0.x, so its minors are breaking by semver, but the CLI's
  scan and exit code are what the image runs.
- **The image holds the binary, Debian's CA bundle** (TLS to
  `grype.anchore.io` and registries), `LICENSE` and `COPYRIGHT`.
