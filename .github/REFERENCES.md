# CI and updates: references

## Sources

- Renovate: `github.com/renovatebot/renovate` (`docs/usage`, managers in
  `lib/modules/manager`, presets in `lib/config/presets/internal`);
  <https://docs.renovatebot.com/>
- Shared workflows, actions and Renovate preset:
  `github.com/spnngl/.github`
- BuildKit attestations:
  <https://docs.docker.com/build/metadata/attestations/>
- Signing: `bootc/REFERENCES.md`, "Signing"

## `build-bootc.yml`

- **Triggers:** push to `main`, Sunday 07:00 Europe/Paris (base and
  package updates, fresh geo-blocking data) and manual runs push; pull
  requests lint and build. Push and pull request runs only when a bootc
  input changed (`paths`: `bootc/` but its scripts and docs, the
  workflow), then rebuild every bootc image: they share most files. A
  failed push is retried by the next change or the weekly rebuild.
- **The matrix is the list of images** (`name`, `version`, and for a
  stage `target`, tag `suffix`, `k3s`), `version` passed as
  `--build-arg BASE_VERSION`; the `push` job reuses it by YAML anchor.
- **`build.sh`'s flags** (`--format=docker`, context `bootc/`), plus an
  `org.opencontainers.image.source` label linking the package to the
  repository, and `--platform` the runner's own. Rootless podman.
- **Native builds, no QEMU:** arm64 as fast as amd64, in parallel. Each
  platform downloads geo-blocking data itself: it can differ slightly.
- **A `push` job per image** merges the platforms' `dir:` folders
  (`podman save --format docker-dir --compress`: OCI would drop
  `SHELL`), artifacts kept one day, into one manifest list; it fails
  rather than push a partial list, and runs even when another image
  failed.

## `build-apps.yml`

Same triggers, runners and tags; Docker tooling only: podman can't run
Dalec, and one way to build, attest and sign is simpler.

- **Found, not listed:** `discover` makes the matrix from
  `containers/*/spec.yml` (`args.BASE_VERSION`, by `yq`) and
  `containers/*/Containerfile` (`ARG BASE_VERSION`).
- **Only what changed:** an image whose folder changed (its docs
  excepted), every one when the workflow changed, on the weekly rebuild
  and manual runs. Since a pull request's base, or for a push the
  workflow's last successful run on the branch: a cancelled or failed
  run never pushed, so the next one builds its changes too. No such run:
  every image.
- **`docker/build-push-action`** on a `docker-container` builder (the
  docker driver can't attest). The image sets its own
  `org.opencontainers.image.source` label.
- **BuildKit attestations** in each platform's index: SLSA provenance
  (`mode=max`, `version=v1`, no secrets) and an SPDX SBOM by syft on the
  final image (dpkg database, `dist-info`, Go modules). Read with
  `docker buildx imagetools inspect <tag> --format '{{ json .Provenance
  }}'` (or `.SBOM`). No `actions/attest-build-provenance`: it would be a
  second provenance.
- **Pushed by digest per platform**, merged by `docker buildx imagetools
  create`, attestations included; then signed with `cosign sign` and
  checked with `cosign verify`.

## Vulnerability scanning

The shared `scan-image` action runs Grype and Trivy: Trivy has no Fedora
data, and their sources differ.

- **Pull requests:** each build job scans its image (OCI layout) and
  fails on a Critical vulnerability with a fix that the pushed image of
  the same tag and platform lacks. The rest is reported: without a fix,
  or already pushed, a pull request can't act on it. No pushed image (a
  new image, a version bump) fails nothing: blocking would keep the
  older image.
- **Pushed images:** `image-scan.yml` scans daily the tags pushed in the
  last 8 days, every platform, and uploads High and Critical findings to
  code scanning. It never fails, nor do pushes and weekly rebuilds:
  failing would keep the older, more vulnerable image on hosts.

## Updates: `renovate.json5`

PRs every Saturday, the day before the weekly rebuild, for every pinned
version. `renovate.yml` validates the config; the shared preset sets
timezone, labels, semantic commits, action digests and automerge under
`.github/`.

- **One PR per dependency, every file at once:** an unmatched pin goes
  stale silently.
- **Major base releases only:** the weekly rebuild follows point
  releases of `BASE_VERSION`, the base's major tag.
- **3 days before a GitHub release or tag** (`minimumReleaseAge`): time
  for a broken or malicious release to be pulled, and for CRI-O to
  publish a Kubernetes minor release. Not for images: Renovate gets their
  dates from Docker Hub only, and holds an update without one.
- **Tags, no digests**, except actions: a digest on `FROM` would freeze
  the base between rebuilds, and land in `ARG BASE_VERSION`, the tag.
- **Automerged once CI passes:** actions (grouped), and minor and patch
  releases of what CI exercises (build tools, applications with a server
  test) or the docs only use (hadolint, Renovate's validator). Each
  image's `AGENTS.md` says which.
- **By hand:** base images, image-builder-cli, every major release, and
  the images whose `AGENTS.md` says so. A new base major or Kubernetes
  minor changes the tag: hosts stay on the old, no longer rebuilt, until
  `bootc switch`.
