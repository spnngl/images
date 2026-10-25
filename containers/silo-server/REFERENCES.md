# silo-server: references

## Sources

- Upstream: `github.com/Silo-Server/silo-server` at the spec's commit:
  `Dockerfile` (build, runtime packages, paths), `go.mod`,
  `web/package.json` and `web/vite.config.ts` (web app),
  `internal/buildinfo` (ldflags), `internal/config` (environment),
  `internal/playback/remux.go` (ffmpeg lookup),
  `internal/jellycompat/web_component.go` (Jellyfin Web),
  `migrations/sql/001_schema.sql` (default paths), `docker-compose.yml`
  (plugins folder, stop time); docs
  <https://siloserver.org>
- ffmpeg fork and its repository: `containers/jellyfin/REFERENCES.md`
- Dalec: `containers/sabnzbd/REFERENCES.md`; `github.com/project-dalec/dalec`
  at the frontend's tag: `source_image.go` (image source)

## Decisions

- **A commit of `main`, tagged by its first 8 characters:** upstream
  has no release or tag (its own image is tagged `build-<n>` and by
  commit). Renovate follows `main` weekly, by hand: tens of commits a
  day, each PR update a rebuild. The package version is
  `0~git<short commit>`; the binary reports the commit and
  `SOURCE_DATE_EPOCH` as its build (`internal/buildinfo`), as
  upstream's CI passes them.
- **Dalec, Go and Node.js built in:** cgo links libvips (bimg) and
  SQLite, so the package gets `libvips42t64` from its shlibs. Go from
  trixie-backports, build only, followed through Repology
  (`containers/nftables-exporter/REFERENCES.md`). Node.js 24 (trixie
  has 20) from the official image as a Dalec source, pinned by digest,
  build only.
- **pnpm through corepack, network in the build sandbox:** Dalec has no
  pnpm generator. `--frozen-lockfile` checks every module against
  `web/pnpm-lock.yaml`'s hashes; corepack checks pnpm's signature.
  `vite build` alone: upstream's `build` script adds a typecheck, which
  writes nothing.
- **No Jellyfin Web compatibility (`silo compat-web`):** it clones and
  builds jellyfin-web at runtime with git and npm, which a shell-less
  image lacks. Silo's own web app and the Jellyfin API remain.
- **`jellyfin-ffmpeg8`:** Silo looks for it first, as upstream's image
  ships it. No Intel OpenCL, as `containers/jellyfin`.
- **Volumes `/var/lib/silo` and `/tmp`:** upstream's paths. Silo stores
  its transcode folder (`/tmp/silo-transcode`) as a database setting,
  with prepared downloads beside it: the whole of `/tmp` keeps the
  defaults working with a read-only root filesystem. Plugins go in
  `/var/lib/silo/plugins` (`SILO_PLUGIN_CACHE_DIR`), as upstream's
  `docker-compose.yml`, which also gives the 2-minute stop.
- **UID/GID 65532, `HOME=/var/lib/silo`:** no passwd entry; fontconfig
  writes its cache in `~/.cache`.
- **Fonts `fonts-noto-core` and `fonts-noto-cjk`:** subtitle burn-in, as
  upstream's image.
- **`libmd0` as a runtime dependency:** `containers/jellyfin/REFERENCES.md`.
