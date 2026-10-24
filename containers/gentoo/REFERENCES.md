# gentoo: references

## Sources

- Gentoo's autobuilds: `https://distfiles.gentoo.org/releases/<arch>/autobuilds/`:
  `latest-stage3-<arch>-<flavor>.txt` (clear-signed: the newest
  stage3's path and size), `<timestamp>/stage3-<arch>-<flavor>-<timestamp>.tar.xz`
  and its `.asc`. About six weekly builds kept per architecture.
- Signatures and keys: <https://www.gentoo.org/downloads/signatures/>
- Unpacking a stage3: <https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Stage>
- Gentoo's own images: `github.com/gentoo/gentoo-docker-images`,
  `stage3.Dockerfile` (fetch, check, unpack) and `build.sh` (Gentoo's
  architecture names against Docker's, for a platform beyond amd64 and
  arm64)
- `sqv --help` (Debian's `sqv`): verification modes, and its output, the
  signing certificate's fingerprint

## Decisions

- **Gentoo's tarball, over Docker Hub's `gentoo/stage3`:** the files
  come from Gentoo's mirror, checked against Gentoo's key; this
  repository builds, scans and signs the image.
- **OpenRC and systemd flavors** (the owner's choice): the profile sets
  the USE flags of what jobs build; the image itself never boots.
  Gentoo's binhost (`releases/<arch>/binpackages/23.0/`,
  `x86-64_musl_hardened` and `arm64_musl_hardened`, their `Packages`)
  serves both: most packages with a `systemd` flag are built both ways.
  `dbus` and `libudev` are built with systemd only, so an OpenRC job
  compiles them.
- **The latest stage3 on each build** (the owner's choice): a pinned one
  is deleted after about six weeks. `ADD` fetches the latest file on
  every build, cache or not, and the unpack step reruns when it changed.
  Gentoo's weekly builds start Sunday afternoon (UTC) or later, so the
  weekly rebuild (`build-apps.yml`, Sunday morning) takes the previous
  week's. amd64 and arm64 build at different times: their stage3s
  differ.
- **Tag: the flavor, rolling** (the owner's choice), OpenRC's without
  `-openrc` (`musl-hardened`), as Gentoo's profiles name OpenRC's
  without a suffix; as `datalists`'
  `latest`: a user pins the digest. No `version` label, its platforms
  carrying different stage3s; no `licenses` label, each package having
  its own (`/var/db/pkg/*/*/LICENSE`).
- **Release key pinned by fingerprint**
  (`13EBBDBEDE7A12775DFDB1BABB572E0E2D182910`, also pinned by Gentoo's
  images): `service-keys.gpg` is fetched unpinned and holds several
  keys, any of which `sqv` accepts.
- **`sqv` verifies:** apt's verifier, already in Debian trixie's image.
- **The stage3's path comes from the verified latest file** and must
  name this architecture and flavor: a signed stage3 of another flavor
  fails. The `.asc` signs the tarball itself, so it is the one check.
- **`curl` fetches the stage3:** its name is only known once the latest
  file is read, after `ADD`. `xz-utils` decompresses it. Both from the
  Debian snapshot (`containers/AGENTS.md`).
- **Unpacked as the handbook does:** `--numeric-owner` (Gentoo's ids),
  `--xattrs --xattrs-include='*.*'` (file capabilities). `COPY --link`
  keeps hard links and setuid bits.
- **File times kept** (`rewrite-timestamp=false`, `docker-bake.hcl`):
  `/var/db/pkg/*/*/CONTENTS` records each file's time, and portage
  keeps a file whose time differs when it unmerges its package
  (`portage/dbapi/vartree.py`, `!mtime`). The `.pyc` files check their
  source's time too. CI's `SOURCE_DATE_EPOCH`, the last commit, is
  older than each new stage3: clamped to it, every time would differ.
- **As Gentoo ships it:** Gentoo's images also set OpenRC's
  `rc_sys="docker"` and a UTC timezone, for a booted container. The
  ebuild repository is the job's (`emerge-webrsync`), current each run.
- **Root, `bash` by default:** emerge installs into the system.
- **Smoke test in the final stage, exec form, `/tmp` a tmpfs:** it runs
  the image's own binaries, leaves an empty layer, and sets no `SHELL`
  for images built on this one. The profile lives in the ebuild
  repository: `emerge --version` prints it unavailable.
- **The vulnerability scans cover language packages only** (the Python
  ones' `dist-info`), not Gentoo's: Grype and Trivy (`scan-image`,
  `image-scan.yml`) have no Gentoo vulnerability source
  (`anchore/vunnel`'s providers, Trivy's `pkg/detector/ospkg`). Gentoo's advisories are GLSAs
  (<https://security.gentoo.org/glsa>); a job checks them with
  portage's `glsa-check` once it has the ebuild repository.
- **amd64 and arm64, which Gentoo names as Docker does:** the platforms
  `build-apps.yml` builds; another fails the first step.
