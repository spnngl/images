# trivy: references

## Sources

- Upstream: `github.com/aquasecurity/trivy` at tag `v<BASE_VERSION>`:
  `goreleaser.yml` (release build), `Dockerfile` (upstream's image),
  `pkg/flag/` (flags and `TRIVY_*` variables, `options.go`),
  `pkg/commands/server/run.go` and `pkg/rpc/server/listen.go` (server,
  `/healthz`, `--token`), `pkg/db/db.go` (DB update and
  `--skip-db-update`), `pkg/cache/dir.go` and `pkg/utils/fsutils/fs.go`
  (cache and data folders), `pkg/notification/notice.go` (update check
  and telemetry)
- `github.com/aquasecurity/trivy-db` at the version `go.mod` names:
  `pkg/db/db.go` (`SchemaVersion`)
- Docs: `https://trivy.dev/latest/docs/`

## Decisions

- **Scratch, no git, no shell:** a scan runs no other program. Upstream's
  image has `git` for `git::` sources (plugins, Terraform modules, VEX
  repositories: go-getter runs it), and Python's license lookup execs
  `python`; both are unavailable and listed in the header. `trivy repo`
  clones with go-git, in the process (`pkg/fanal/artifact/repo/git.go`).
- **Upstream's release build:** `CGO_ENABLED=0`, `-s -w`, `-extldflags
  '-static'` and `-X ...pkg/version/app.ver=<version>`; no git is read,
  so no `--keep-git-dir`. `-trimpath` is added (reproducible paths).
  The `golang` image's Go, newer than `go.mod`'s: the standard library's
  fixes.
- **Commit pinned** (`ADD --checksum`): the tag must resolve to it, tags
  can be moved.
- **Built and tested as UID 65532:** neither the build nor the test run
  as root, and the source stays root's. Go cache ids are
  `containers/minio`'s, the same user.
- **Smoke test in the build stage, offline:** Renovate automerges Trivy
  and `golang` bumps (the user's choice: a broken release is fixed by
  the next bump), and nobody upstream tests this build. It uses an empty
  database, not the real one: that is a 137 MB download from `ghcr.io`
  that unpacks to 1.6 GB, per platform and per build, and it would make
  the build depend on `ghcr.io`. Trivy opens the DB read-only
  (`pkg/db/db.go`), so a bbolt file made by a small Go program stands
  in for it, with a `metadata.json` at the schema version
  `--skip-db-update` checks (`db.SchemaVersion`, read from the module).
  The secret rule is the test's, as secret scanning needs no database:
  in client/server mode the client scans and the server returns the
  findings. The key is Trivy's own test key (`scanner_test.go`): AWS's
  documented example is allow-listed by Trivy's `examples` rule.
- **`/var/cache/trivy` as a volume, owned by 65532:** the databases are
  large (1.6 GB and the Java DB) and a run downloads them when missing.
  A new Docker volume takes the folder's owner. Parents stay root's.
- **`XDG_DATA_HOME` in the volume:** Trivy's plugins, modules and VEX
  repositories go under `$XDG_DATA_HOME/.trivy`, or `$HOME/.trivy`
  (`fsutils.HomeDir`), and `HOME` is unset without a passwd entry: they
  would not persist, or fail to write.
- **`TRIVY_LISTEN=0.0.0.0:4954`:** the flag's default is
  `localhost:4954`, unreachable from outside the container. Only
  `server` reads it. A variable, so it stays when `CMD` is replaced.
- **Telemetry and update check off:** with neither flag, each run sends a
  request to `check.trivy.dev` (`notice.go`), and both flags are
  needed to skip it. The image is the update.
- **Templates in `/contrib/`:** upstream's image path, so the
  documentation's `@/contrib/<name>.tpl` works.
- **`WORKDIR /src`:** a mount point for what is scanned, root's, as
  `containers/kustomize`.
- **`/tmp`, root's, 1777:** clones and image layers are written to
  `os.TempDir()`; a tmpfs mounted over it takes the mode.
- **The image holds the binary, Debian's CA bundle** (the databases on
  `ghcr.io`, image registries), the templates, `LICENSE` and `NOTICE`.
- **No `HEALTHCHECK`:** no curl in the image, and Kubernetes ignores it;
  probe `/healthz`.
- **No `CMD`, `ENTRYPOINT` the absolute path:** as upstream's, whose
  arguments are Trivy's.
- **Automerged, `depType=automerge`:** patch and minor releases; majors
  wait (`renovate.json5`).
