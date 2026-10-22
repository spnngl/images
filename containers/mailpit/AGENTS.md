# mailpit

Mailpit (SMTP server that catches mail for testing, web UI and API, Go):
upstream's release built from source as tagged, no patch, one static
binary on `scratch`, its web UI built in a Node stage and embedded.
Runtime contract: the Containerfile's header. Upstream sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The build stages run as UID 65532, with cache ids of their own
  (`npm-65532`; the Go ones shared with `containers/minio`).
- Settings that must survive a replaced `CMD` go in the environment
  (`MP_*`), as `MP_DATABASE` and `MP_DISABLE_VERSION_CHECK` do.
- Commands the image runs call `version` with `--no-release-check`:
  without it, `version` queries GitHub.
- Probes: `GET /livez` and `/readyz` on 8025; `mailpit readyz`, the
  `HEALTHCHECK`, reads `MP_UI_BIND_ADDR` and `MP_WEBROOT`.

## Smoke tests

The build stage's server test: `mailpit readyz --wait`, a 401 without the
random UI credentials, `/dist/app.js` served (the UI is embedded), a
message sent over SMTP and found by its subject through
`/api/v1/message/latest`. The final stage runs `mailpit version`.

## Updates

Renovate follows the `v<x.y.z>` tags; minor and patch releases automerge
on the server test (`depType=automerge`), majors by hand. For a major,
or a failed build, check against upstream's tag:

- the build: `.github/workflows/build-release.yml` (Node version, `npm`
  scripts, ldflags) and `Dockerfile`; `server/ui/dist` identical with
  and without `--ignore-scripts` (REFERENCES.md);
- the image's variables and flags (`MP_DATABASE`,
  `MP_DISABLE_VERSION_CHECK`, `readyz`, `version --no-release-check`):
  `cmd/root.go`, `cmd/readyz.go`, `cmd/version.go`;
- the database: a release can migrate `/data/mailpit.db`
  (`internal/storage/schemas/`), with no way back.

The `node` image's major is the one upstream's release uses: Renovate's
`node` major PRs merge when upstream moves. A checksum-only update means
upstream moved the tag.
