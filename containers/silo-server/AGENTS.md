# silo-server

Silo (media server, Go, React web app embedded) built with Dalec from
`spec.yml`, on the model of `containers/sabnzbd`: one Debian trixie
package, installed with jellyfin-ffmpeg8 into a shell-less image.
Runtime contract: the spec's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md). Not `containers/silo`: that
one is pgsty/silo, an S3 server.

## Gotchas

- Silo needs PostgreSQL with pgvector and Redis: the image's tests only
  run `silo -h`. A run check needs both (`docker run` of
  `pgvector/pgvector` and `redis`), then GET `/api/v1/health` and no
  `WARN` in the log. Docker copies the image's root-owned
  `/var/lib/silo` into a new named volume: mount it `:nocopy`, chowned
  to 65532.
- Silo stores its paths (`playback.transcode_dir`, `/tmp/silo-transcode`)
  in the database: keep them in the volumes when changing them.

## Updates

Never automerged; proposed on Saturday (`renovate.json5`). Every update
is checksum-only: a new commit of `main`, not a moved tag. Before
merging it, read upstream's changes from the PR's link, checking:

- `go.mod`'s `go` directive: newer than `golang-1.27-go` fails the
  build; Renovate's `golang-go` PR brings the Go that fixes it.
- `Dockerfile` and `docker-compose.yml`: a new runtime package, path or
  environment variable goes in the spec (header, dependencies, volumes).
- `web/package.json`: a `packageManager` or Node.js major change.
  Corepack ships with Node.js up to 24: a newer node image needs pnpm
  another way.
- `migrations/sql/`: a new default path outside the volumes.

A new node major release comes as its own PR, merged by hand: upstream's
Dockerfile names the major it builds with.
