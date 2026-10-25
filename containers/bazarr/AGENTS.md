# bazarr

Bazarr (subtitle manager for Sonarr and Radarr, Python) as a Containerfile
on distroless' `python3-debian13`: upstream's release files at the tag,
its web app built here, the compiled Python modules from the
hash-pinned `bazarr.lock` (PyPI wheels), and Debian's FFmpeg and unrar
copied with their libraries and dpkg status (the way
`containers/haproxy` copies its libraries). Runtime contract:
the Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **The process is `bazarr/main.py`, not upstream's `bazarr.py`:** the
  launcher would be PID 1 over a child it doesn't signal. `STOPFILE` and
  `RESTARTFILE` (ENV) are what the launcher would set. SIGINT stops Bazarr
  with status 156; the UI's Restart and Shutdown end the container: run it
  with a restart policy.
- **Debian's tools on `PATH`, no download:** Bazarr fetches a missing
  binary into its install folder (`bazarr/utilities/binaries.py`), root's
  here: a tool off `PATH` fails the start, and the smoke test.
- **`bazarr.lock` is the only source of the compiled modules:** the
  build installs it with `--require-hashes --only-binary :all:`, then
  checks that upstream's requirements files are satisfied by it.
- **Done when** the build passes: its last instruction runs
  `smoke-test/smoke_test.py` in the final image (unrar, FFmpeg's
  filters Bazarr's Whisper provider uses, ffprobe, the compiled modules'
  imports, Bazarr's start, its version and API, SIGINT), and `/bin/sh` is absent from the image
  (`docker create`, then `docker export | tar -t`).

## Updates

Automerged for patch and minor releases (Bazarr, uv), when the build
passes. Before merging a PR of a new Bazarr or uv: run
`containers/bazarr/bazarr-lock.sh` and commit `containers/bazarr/bazarr.lock`
if it changed. The build fails at *uv pip install --dry-run* when
upstream's requirements moved past the lock (a new module, a changed
bound): run the script, then read upstream's `requirements.txt`,
`postgres-requirements.txt` and `.github/files_to_copy` for changes the
Containerfile should follow. The node image: the build fails when its
major differs from `frontend/.nvmrc`'s; move the `FROM` to that major.
A checksum-only update means upstream moved the tag. Beta tags
(`v1.6.3-beta.N`) are not releases: Renovate's `github-tags` picks stable
versions only.
