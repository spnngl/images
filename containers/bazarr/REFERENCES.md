# bazarr: references

## Sources

- Upstream: `github.com/morpheus65535/bazarr` at tag `v<BASE_VERSION>`:
  `bazarr.py` (the launcher), `bazarr/main.py`, `bazarr/init.py`
  (`package_info`, `init_binaries`), `bazarr/app/get_args.py`
  (`NO_UPDATE`, `--config`), `bazarr/utilities/central.py` (stop and
  restart files), `bazarr/utilities/binaries.py`,
  `.github/files_to_copy` and `.github/scripts/create_asset.sh` (the
  release archive), `.github/workflows/release_dev_to_master.yaml` (the
  web app's build), `frontend/.nvmrc`, `requirements.txt`,
  `postgres-requirements.txt`
- Docs: <https://wiki.bazarr.media/> (environment variables, PostgreSQL)
- Distroless: `github.com/GoogleContainerTools/distroless`, `python3/`,
  `cc/` and `base/` (what `python3-debian13` holds,
  `/var/lib/dpkg/status.d`)
- uv: <https://docs.astral.sh/uv/pip/compile/> and `.../packages/`
  (`--generate-hashes`, `--require-hashes`, `--only-binary`, `--dry-run`)
- Debian: `packages.debian.org/trixie/ffmpeg`, `.../unrar`
  (non-free, `unrar-nonfree` and its alternative)
- The Dalec image of a Python app: `containers/sabnzbd` (same lock
  script, `requirements.lock`)

## Decisions

- **A Containerfile on distroless' `python3-debian13`, not Dalec:** the
  interpreter, its libraries, a passwd entry for 65532 and a Debian
  trixie base come from the image; the build adds the few packages it
  lacks, as `containers/haproxy` does. The build stage installs the wheels
  with uv: no Dalec package of every module.
- **Process `bazarr/main.py`, `STOPSIGNAL SIGINT`, no launcher:**
  `bazarr.py` spawns `main.py` and polls stop and restart files every
  5 s; its SIGINT handler doesn't reach the child, so as PID 1 it would
  stop with its child orphaned. `main.py` handles SIGINT itself
  (`bazarr/app/server.py`): the database closes, the process exits.
  Restart and Shutdown, the UI's, write a file the launcher reads and
  then exit: here they end the container, which a restart policy brings
  back. `STOPFILE` and `RESTARTFILE` are read by `central.py` with
  `os.environ[...]` (a `KeyError` when unset), so the image sets them,
  in `/tmp`.
- **Exit status 156 on SIGINT:** `os._exit(-100)` (`EXIT_INTERRUPT`) is
  156 as an exit status; nothing to fix, only to document,, as
  orchestrators read it as a failure.
- **`NO_UPDATE=true`, `package_info` `UpdateMethod=External`:** the image
  is the release. `NO_UPDATE` skips the pip installs of `init.py`
  (its modules are in `libs/`) and the self-update; `package_info`
  turns the UI's updater off and says why.
- **Upstream's release archive, rebuilt from the tag:** the
  `files_to_copy` list and `VERSION` (`bazarr/main.py` reads it, without
  git), installed in `/usr/lib/bazarr`, root's: Bazarr can't rewrite its
  code. The web app is built from the source, as the workflow does,
  with `npm ci` for the lockfile's versions and integrity hashes
  (`npm install` may move them) and `--ignore-scripts` (husky needs
  git). Node's major is `.nvmrc`'s, checked by the build.
- **Compiled modules from the lock, installed into `libs/`:**
  `requirements.txt` has lxml, numpy, Pillow, webrtcvad and
  setuptools; `postgres-requirements.txt` psycopg2. The lock pins each
  with its hashes (every wheel of the release, both architectures),
  installed with `--only-binary :all:`: no compiler in the image build.
  Debian trixie has no `python3-webrtcvad`. `libs/` is Bazarr's
  `sys.path` (`bazarr/app/libs.py`); the vendored modules there don't
  overlap the lock's. The Windows module (`pywin32`) is dropped by
  `--python-platform linux`; `--only-binary=Pillow` in `requirements.txt`
  is stripped, uv takes per-requirement options for hashes only.
- **The gate:** `uv pip install --dry-run --offline` of upstream's own
  requirements files against the installed environment: an upstream bump
  (a new module, a raised bound) fails the build, never ships silently.
- **Debian's FFmpeg 7.1 and unrar, not upstream's static builds:** the
  SBOM and the scanners see Debian's packages; upstream's would be
  downloaded at run time (`binaries.json`), unverified. Bazarr looks for
  them on `PATH` first (`get_binary`, `whichcraft`). FFmpeg is
  trixie's, patched by Debian's security team: the snapshot moves it. The
  repository's snapshot has `non-free` for unrar only
  (`sed` of `debian.sources`).
- **FFmpeg's libraries copied as packages, with their status:** ~210
  packages (Mesa, codecs, filters, BLAS: the dependency closure of
  Debian's build), as the SBOM lists them. The closure is found from
  `ldd` of the binaries, minus what distroless has; libraries FFmpeg only
  `dlopen`s (VA-API, VDPAU drivers: hardware decoding, never requested)
  stay out. `dpkg-query -S` fails the build for a library no package owns.
  The image is large (~800 MB): a smaller FFmpeg means a build of its
  own, with Bazarr's codecs to chase.
- **`unrar` linked as `/usr/bin/unrar`:** Debian's package registers
  `unrar` with `update-alternatives` in its postinst, which the copy
  doesn't run. Bazarr tries `unar`, `unrar`, `7z` in that order, and
  raises `BinaryNotFound` without one.
- **Bytecode compiled at build, `unchecked-hash`:** the install folder is
  root's, so Python can't write `__pycache__` at run time and would
  compile each start in memory. The CI clamps file times, so
  time-checked `.pyc` files would look stale. `-W ignore`: vendored libs
  have invalid escape sequences that warn at compile.
- **Smoke test in the final stage, a Python script:** the image has no
  shell, and `curl` isn't in it; the test runs with the image's own
  interpreter, as the image's user, on the image's files (ENTRYPOINT,
  ENV), so a missing library, a wrong path or a root-only file fails
  here. It checks the tools (unrar, FFmpeg's filters the Whisper
  provider chains, ffprobe), the imports of the compiled modules (with
  `NO_UPDATE`, Bazarr's own start-up check is skipped), then the server: `/api/system/ping`,
  `/api/system/status`'s version (needs the API key, read from
  `config.yaml`), and the order of the stop.
- **`/tmp` a volume, `/config` another:** with a read-only root, Bazarr
  writes its config, database, logs and cache under `--config`, and
  temp files and the stop and restart files under `/tmp`.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments' (`GET /api/system/ping`, unauthenticated).
- **License `GPL-3.0-only`:** upstream's GPL v3 text carries no "or any
  later version".
- **Versions:** `depType=automerge`: the smoke test, the gate and the
  build cover what a patch or minor release breaks. `versioning=semver`:
  Bazarr's beta tags (`v1.6.3-beta.N`) are pre-releases, not
  candidates.
