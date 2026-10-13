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

- **Found, not listed:** `discover` makes the matrix from the targets
  of `docker buildx bake --print '*'` on `containers/docker-bake.hcl`
  and every `containers/*/docker-bake.hcl`: one item per image, line
  and Debian release, with its context, file, build arguments and tags.
- **Only what changed:** a target whose resolved definition differs from
  the base's (the same `--print`, on a worktree of the base: a bumped
  version, a new line), or whose folder changed (its docs and Bake file
  excepted), every one when the workflow changed, on the weekly rebuild
  and manual runs. Since a pull request's base, or for a push the
  workflow's last successful run on the branch: a cancelled or failed
  run never pushed, so the next one builds its changes too. No such run:
  every image.
- **Bake only describes, the workflow builds:** `docker/github-builder`'s
  Bake workflow pushes before anything else, which leaves no place for
  the scan on pull requests, and builds one target per call. The item's
  build arguments go to `docker/build-push-action`, plus
  `SOURCE_DATE_EPOCH` from the last commit (Bake's file can't hold it: it
  would change on every commit).
- **`docker/build-push-action`** on a `docker-container` builder (the
  docker driver can't attest). The image sets its own
  `org.opencontainers.image.source` label.
- **BuildKit attestations** in each platform's index: SLSA provenance
  (`mode=max`, `version=v1`, no secrets) and an SPDX SBOM by syft on the
  final image (dpkg database, `dist-info`, Go modules). Read with
  `docker buildx imagetools inspect <tag> --format '{{ json .Provenance
  }}'` (or `.SBOM`). No `actions/attest-build-provenance`: it would be a
  second provenance.
- **Pushed by digest per platform**, merged with attestations by one
  `docker buildx imagetools create` for all the item's tags, each tag
  signed with `cosign sign` and checked with `cosign verify`; the scan's
  baseline is the first tag.

## Vulnerability scanning

The shared `scan-image` action runs Grype and Trivy: Trivy has no Fedora
data, and their sources differ.

- **Pull requests, bootc:** each build job scans its image (OCI layout)
  and uploads High and Critical findings to code scanning, in
  `image-scan.yml`'s categories, so the pull request shows what it
  adds. It never fails: its findings are triaged there, not in the
  pull request.
- **Pull requests, applications:** each build job scans its image (OCI
  layout) and fails on a Critical vulnerability with a fix that the pushed image of
  the same tag and platform lacks. The rest is reported: without a fix,
  or already pushed, a pull request can't act on it. No pushed image (a
  new image, a version bump) fails nothing: blocking would keep the
  older image.
- **Pushed images:** `image-scan.yml` scans daily the tags pushed in the
  last 8 days, every platform, and uploads High and Critical findings to
  code scanning. It never fails, nor do pushes and weekly rebuilds:
  failing would keep the older, more vulnerable image on hosts.

## Updates: `renovate.json5`

PRs open as releases come; the Debian snapshot and base digests wait for
Saturday, the day before the weekly rebuild. `renovate.yml` validates the
config; the shared preset sets timezone, labels, semantic commits, action
digests and automerge under `.github/`.

- **One PR per dependency, every file at once:** an unmatched pin goes
  stale silently.
- **Major base releases only:** the weekly rebuild follows point
  releases of `BASE_VERSION`, the base's major tag.
- **3 days before a GitHub release or tag** (`minimumReleaseAge`): time
  for a broken or malicious release to be pulled, and for CRI-O to
  publish a Kubernetes minor release. Not for images: Renovate gets their
  dates from Docker Hub only, and holds an update without one.
- **Digests on actions and application images' `FROM`**, tags on bootc
  bases: a digest there would freeze the base between rebuilds, and land
  in `ARG BASE_VERSION`, the tag. An application image's version is in
  its Bake file, so a digest costs nothing: its updates are grouped with
  the Debian snapshot, automerged (the images' build and smoke test run
  on the pull request).
- **One manager for every Bake file:** a `# renovate:` comment before
  each version names its datasource and lookup fields; the next line's
  quoted version and checksum are what Renovate replaces (the checksum
  as `currentDigest`: a git tag's commit, peeled). `renovate.yml`'s
  `extract` job fails on a comment Renovate doesn't pick up. The
  `debian-snapshot` custom datasource lists `snapshot.debian.org`'s
  timestamps; Debian's packages follow the weekly bump.
- **Automerged once CI passes:** actions (grouped), and minor and patch
  releases of what CI exercises (build tools, applications with a server
  test) or the docs only use (hadolint, Renovate's validator). Each
  image's `AGENTS.md` says which.
- **By hand:** base images, image-builder-cli, every major release, and
  the images whose `AGENTS.md` says so. A new base major or Kubernetes
  minor changes the tag: hosts stay on the old, no longer rebuilt, until
  `bootc switch`.
