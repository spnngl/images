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
- Copilot cloud agent: `github.com/github/docs`,
  `content/copilot/how-tos/use-copilot-agents/cloud-agent/`
  (`use-cloud-agent-on-github.md`, "Continuing work on a pull
  request"; `troubleshoot-cloud-agent.md`)

## `build-bootc.yml`

Same triggers, runners, actions and tags as `build-apps.yml` (below): its
jobs `discover`, `hadolint`, `build` and `push` run `bake-discover`,
`bake-build` and `bake-push`. What differs:

- **Found, not listed:** `bake --print` of the root `docker-bake.hcl`,
  `bootc/docker-bake.hcl` and every `bootc/*/docker-bake.hcl`: one
  target per image (`fedora-45`, `almalinux-10`, `fedora-coreos-1-36`,
  `fedora-coreos-nvidia-1-36`). Not `containers/`'s: two files define a
  `tags()` each. Only what changed: the image's own files, as read by
  its `Containerfile.dockerignore`; a change of `bootc/fedora/` rebuilds
  almalinux, which reads it, and none of fedora-coreos's.
- **BuildKit for every image**, not podman: one builder, one cache, the
  same provenance and SBOM attestations as the applications. podman's
  `/run/.containerenv` would turn fedora-coreos's OpenSCAP machine rules
  off (`bootc/fedora-coreos/REFERENCES.md`).
- **fedora-coreos's reports:** its amd64 build also exports the
  `-reports` target (artifact `reports_<id>`), whose `check` stage fails
  the job on a failed rule, a fixable Critical or a failed goss check.
- **fedora-coreos's VM tests gate its push** (job `vm-test`, on pull
  requests too, the targets of the `vm-test` group): `vm-test` boots the
  amd64 image in a test VM and runs the goss suites
  (`bootc/fedora-coreos/REFERENCES.md`, "VM tests in CI"). On pull
  requests the build job keeps its OCI layout; on pushes `vm-test` pulls
  the digest it pushed untagged. A job-level `if` can't read the matrix,
  so `push` runs for every target, and its `tested` step fails the
  fedora-coreos entries alone unless their line's `vm-passed_<id>`
  artifact exists. The GPU image follows its line's tests: it differs
  from fedora-coreos by one stage. When only the GPU image changed (an
  NVIDIA version), its line's image isn't built, so no VM test runs and
  the GPU image is pushed after its build's scans and goss checks alone:
  its nvidia stage is what changed, and no VM test has a GPU.
- **`release-os`, one release per fedora and almalinux image** that
  changed: its qcow2 from the pushed digest, booted in qemu with a
  throwaway key before it is published (`bootc/REFERENCES.md`, "Disks
  carry no user"). Found in `discover`'s targets (their Containerfiles'
  folders), not in a Bake group: a group is one name in one file, and
  each file would replace the other's.
- **The `release` job** makes one GitHub release per fedora-coreos line
  when it or its GPU image changed (group `disk-image`): the OpenStack
  qcow2 of each, built from the pushed digest, the newest 3 of a line
  kept.
- **A test run** (manual, input `test`) checks the push and release
  jobs from a branch: every tag gets `-test` (`TAG_SUFFIX` of
  `bootc/docker-bake.hcl`) and every release is a prerelease of that
  name, so hosts and nodes, which follow the tags without it, never get
  its images. The clean-up of releases skips prereleases: delete a test
  run's tags and releases by hand.
- **`gate-bootc` is the required check** (`gate`, build-apps.yml's):
  both workflows run on every pull request and skip what didn't
  change, so each gate always runs and passes. The matrix jobs' names
  change with the images, so no ruleset can require them.
- **Native builds, no QEMU:** arm64 as fast as amd64, in parallel. Each
  platform downloads geo-blocking data itself: it can differ slightly.
- **fedora-coreos's scan is a build check, not a report:** a fixable
  Critical fails every build (pull request, push, weekly); an image the
  build can't fix is ignored at its exact version
  (`bootc/fedora-coreos/REFERENCES.md`).

## `build-apps.yml`

Same triggers, runners and tags; Docker tooling only: podman can't run
Dalec, and one way to build, attest and sign is simpler.

- **Found, not listed:** `discover` makes the matrix from the targets
  of `docker buildx bake --print '*'` on the root `docker-bake.hcl`
  (`line()`), `containers/docker-bake.hcl` and every
  `containers/*/docker-bake.hcl`: one item per image, line and Debian
  release, with its context, file, tags and entitlements. It is the
  `bake-discover` action, shared with `build-bootc.yml`.
- **Only what changed:** a target whose resolved definition differs from
  the base's (the same `--print`, on a worktree of the base: a bumped
  version, a new line), or one of whose files changed: those its
  `.dockerignore` keeps (`<Containerfile>.dockerignore` first, then the
  context's, as BuildKit reads them), its Containerfile or spec, and the
  ignore files (docs, kept out by `.dockerignore`, don't count); every one
  when the workflow or an action changed, on the weekly rebuild and
  manual runs. Since a pull request's merge commit's first parent (the
  base branch it merges into: the event's `base.sha` is older when the
  branch moved since), or for a push the workflow's last successful run
  on the branch: a cancelled or failed run never pushed, so the next one
  builds its changes too. No such run: every image.
- **A pull request changing the workflow or an action builds a sample**
  (`sample` of `bake-discover`): `build-apps.yml`'s 67 images take hours
  on the runners, while a CI change breaks by kind of image (a
  Containerfile, a Dalec spec, an entitlement), not by image. The push
  that merges it builds every image, as a change of the workflow. The
  bootc images have no sample: four kinds, four images.
- **`discover.jq` has tests** (`.github/actions/bake-discover/test.sh`,
  run by `shellcheck.yml`): what a target reads decides every build, and
  a `.dockerignore` rule is easy to get wrong.
- **Bake describes, our actions run it:** `docker/github-builder`
  (v1.19.0) pushes before anything else, which leaves no place for the
  scan on pull requests, and its `bake.yml` builds one target per call
  and signs keyless only (the hosts check a key, `bootc/REFERENCES.md`,
  "Signing"). `docker/bake-action` (v7.5.0) builds on our runners; its
  `source: .` builds the checkout, not the Git context it defaults to.
  The workflow sets only what CI decides, with `set`: the platform, the
  cache, the output (Bake names every export after the target's `tags`,
  which would push them: `tags=` is cleared) and `SOURCE_DATE_EPOCH`:
  the time of the last commit of the files the build reads (see "Only
  what changed") and of the Bake files beside them (the Debian
  snapshot), docs excepted. Per image, not per commit as
  `build-bootc.yml`'s podman images: the Containerfiles set it as `ENV`
  before their first `RUN`, so each new value misses the build cache. A
  target that sets it itself keeps its own. Bake can't read git history.
- **One export per build:** an image pushed by digest and an OCI archive
  of the same build report one digest, and it isn't the pushed one
  (spike: `imagetools create` failed with `not found`). Pushes export
  the image alone; pull requests, the OCI layout alone.
- **`rewrite-timestamp` from the target's `output`, on by default:**
  an image whose file times matter turns it off (`containers/gentoo`:
  portage records each file's time, and skips a file whose time
  differs). `output` is the one Bake attribute that holds an export
  option, and the workflow reads that option alone: its own outputs
  replace the rest. Not an `args` entry: a Containerfile warns on an
  argument it doesn't read, Dalec fails on it.
- **`allow` from the target's `entitlements`:** an image whose build runs
  something privileged asks for it in Bake (`containers/buildkit`: its
  smoke test starts a daemon, which `security.insecure` lets create a
  user namespace). The workflow reads that attribute and passes it to
  `bake-action` (`allow`); setup-buildx's default builder permits
  `security.insecure` and `network.host` (`defaultBuildkitdFlags`), so
  nothing else changes, and a target that names none gets none.
- **`docker/setup-buildx-action`** on a `docker-container` builder (the
  docker driver can't attest). The image sets its own
  `org.opencontainers.image.source` label.
- **Build cache in the Actions cache** (`type=gha`,
  <https://docs.docker.com/build/cache/backends/gha/>): each job's
  builder starts empty. One scope per target and platform: jobs sharing
  one overwrite each other's. `mode=max`: the build stages hold the
  work. Export errors ignored: fork pull requests can't write. Pull
  requests read `main`'s cache; `main` reads only its own. Weekly and
  manual rebuilds build without it (`no-cache`) and refresh it: Dalec's
  and Alpine's packages follow their archive (`containers/AGENTS.md`),
  and a cached step keeps the old ones. Hits are mostly re-runs and
  rebuilds of unchanged images: a version or snapshot bump changes build
  arguments every `RUN` reads.
- **The bootc images' build cache in ghcr.io**
  (`ghcr.io/spnngl/images/buildcache`, `cache-repository` of
  `bake-build`, <https://docs.docker.com/build/cache/backends/registry/>),
  not the Actions cache: a repository has 10 GB of it, which the bootc
  images' stages alone filled (10.9 GB on PR #295), evicting the
  applications'. Tag `<id>_<arch>`; a pull request writes
  `<id>_<arch>-pr-<number>`, and reads main's too, as the Actions cache
  scopes a pull request's. `build-bootc.yml`'s weekly run deletes the
  versions not updated in 14 days: main's tags are rewritten every week,
  a closed pull request's are not. fedora-coreos's cache gives smaller
  node downloads (`bootc/fedora-coreos/REFERENCES.md`, "Layers"). Its
  reports target is built in the same Bake call as the image, where
  BuildKit shares their stages, `no-cache` too: the image pushed is the
  one scanned.
- **BuildKit attestations** in each platform's index: SLSA provenance
  (`mode=max`, `version=v1`, no secrets) and an SPDX SBOM by syft on the
  final image (dpkg database, `dist-info`, Go modules). Read with
  `docker buildx imagetools inspect <tag> --format '{{ json .Provenance
  }}'` (or `.SBOM`).
- **Signed provenance on top:** `actions/attest-build-provenance` on the
  manifest list, keyless (the workflow's identity) with a Rekor entry, a
  Sigstore bundle behind OCI referrers. BuildKit's provenance is
  unsigned: Kubernetes admission (Kyverno,
  `codeberg.org/lola_2lannoy/apps`, `sig-spnngl-images.yaml`) trusts
  only this one, by the workflow file's identity. Renaming
  `build-apps.yml` breaks deployments until the policy follows.
- **Pushed by digest per platform**, merged with attestations by one
  `docker buildx imagetools create` for all the item's tags, each
  ghcr.io tag signed with `cosign sign` and checked with `cosign
  verify`; the scan's baseline is the first tag.
- **Docker Hub too:** `tags()` (`containers/docker-bake.hcl`) gives
  each version on ghcr.io and on `docker.io/loladelannoy/<name>`: Docker
  Hub has no nested namespace, so one repository per image, created by
  its first push. Built and scanned once, on ghcr.io; `imagetools create`
  copies the blobs to Docker Hub (`commands/imagetools/create.go` of
  `github.com/docker/buildx`, one copy per repository of the tags), with
  BuildKit's attestations: one digest on both. Docker Hub's copy isn't
  signed nor given signed provenance: cosign's manifest reads there hit
  its pull rate limit (`TOOMANYREQUESTS`), and hosts and Kubernetes
  admission trust ghcr.io alone. Credentials:
  `vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN`, a personal
  access token, Read & Write; the build jobs log in too, for
  authenticated pulls of what the mirror below misses.
- **Pulls through `mirror.gcr.io`:** Docker Hub's pull rate limit
  (`429 Too Many Requests`) is the account's, shared by every build job.
  `mirror.gcr.io`, Google's cache of Docker Hub, serves its images
  unchanged (same digests, so the pinned ones still hold), outside that
  limit. The builder's image is pulled from it (setup-buildx's
  `driver-opts`, its default tag), and BuildKit's `docker.io` pulls go to
  it first: the bases, the `# syntax=` frontend, the SBOM scanner
  (`buildkitd-config-inline`). BuildKit tries the mirrors in order, then
  `docker.io` (`util/resolver/resolver.go` of `github.com/moby/buildkit`,
  `NewRegistryConfig`); the builder's image has no fallback. Second
  mirror, in case Google's cache lacks an image or fails:
  `public.ecr.aws/docker`, AWS's copy of Docker Hub's official images
  (`docker.io/library/*` only: not `docker/dockerfile`, `moby/buildkit`
  nor the SBOM scanner), anonymous pulls under ECR Public's per-IP
  limits. A mirror's path goes after `/v2`
  (`newMirrorRegistryHost`): `library/<image>` is fetched as
  `public.ecr.aws/docker/library/<image>`, checked with a local build.
  Not Microsoft's `mcr.microsoft.com/mirror/docker/library`: a few
  hand-picked images and tags (it has `debian:trixie`, but not
  `debian:trixie-slim`, `golang`, `rust`, `node` nor `alpine` at the
  tags pinned here), so nearly every pull would miss and cost a request.
  Not a mirror of our own: nothing to copy, sign or update.
- **One `gate` job, the check the `main` ruleset requires:** passes
  when every lint and build job passed or was skipped. The build jobs
  are named after the images that changed, so none can be required
  itself. Without a required check pending, GitHub refuses the
  auto-merge Renovate enables on a new PR, and the PR waits for
  Renovate's next run. Its source in the ruleset: GitHub Actions, so no
  other app or commit status can pass it.

## Vulnerability scanning

The shared `scan-image` action runs Grype and Trivy: Trivy has no Fedora
data, and their sources differ.

- **Pull requests, bootc:** each build job scans its image as the
  applications' do, but never fails (`fail: false`): a bootc image holds
  a whole distribution, whose fixes come with the base's next release.
  fedora-coreos's own scans fail every build instead (pull request,
  push, weekly) on a fixable Critical: its `check` stage writes
  `reports/failed`, which fails the build job; an image the build can't
  fix is ignored at its exact version (`bootc/fedora-coreos/REFERENCES.md`).
- **Pull requests, applications:** each build job scans its image (OCI
  layout) and fails on a Critical vulnerability with a fix that the pushed image of
  the same tag and platform lacks. The rest is reported: without a fix,
  or already pushed, a pull request can't act on it. No pushed image (a
  new image, a version bump) fails nothing: blocking would keep the
  older image.
- **Pushed images:** `image-scan.yml` scans daily the tags pushed in the
  last 8 days, every platform, and uploads High and Critical findings to
  code scanning. It never fails, nor do pushes and weekly rebuilds:
  failing would keep the older, more vulnerable image on hosts. Its
  packages are found as the builds find their images (the repositories
  of the bootc Bake targets' tags, the application Bake files' folders):
  a new image needs no edit.

## Updates: `renovate.json5`

PRs open as releases come; the Debian snapshot and base digests wait for
Saturday, midnight to 5am, the day before the weekly rebuild; Renovate's
image waits for the night. `renovate.yml` validates the config; the shared preset sets
timezone, labels, semantic commits, action digests and automerge under
`.github/`.

- **One PR per dependency, every file at once:** an unmatched pin goes
  stale silently.
- **Major base releases only:** the weekly rebuild follows point
  releases of a bootc base's major tag (the `base` matrix of
  `bootc/fedora/docker-bake.hcl` and `bootc/almalinux/docker-bake.hcl`).
- **3 days before a GitHub release or tag, an *arr app's release, an
  npm package or a crate** (`minimumReleaseAge`): time for a broken or
  malicious release to be pulled, and for CRI-O to publish a Kubernetes
  minor release. npm's signatures don't catch a release published with
  a stolen token, and configarr's pnpm and fluffychat's wasm-pack (a
  crate) are automerged and run with the network. Not for images: Renovate gets their dates from Docker Hub
  only, and holds an update without one.
- **Digests on actions and application images' `FROM`**, tags on bootc
  bases: a digest there would freeze the base between rebuilds, and land
  in the Bake variable that holds the tag (`BASE_VERSION`'s value). An application image's version is in
  its Bake file, so a digest costs nothing: its updates are grouped with
  the Debian snapshot, automerged (the images' build and smoke test run
  on the pull request).
- **One manager for every Bake file:** a `# renovate:` comment before
  each version names its datasource and lookup fields; the next line's
  quoted version and checksum are what Renovate replaces (the checksum
  as `currentDigest`: a git tag's commit, peeled). `renovate.yml`'s
  `extract` job fails on a comment Renovate doesn't pick up. The
  `debian-snapshot` custom datasource lists `snapshot.debian.org`'s
  timestamps; Debian's packages follow the weekly bump. The `servarr`
  one reads the update feed the *arr apps' updaters read: each
  release's archive sha256 (`digest`), so tracking downloads nothing
  (`containers/prowlarr/REFERENCES.md`). `crates-io` reads a crate's
  versions from crates.io's API, each with its `.crate` checksum and
  publish date (the built-in `crate` datasource gives no checksum), and
  `crates-io-date` the same releases' publish dates, as the
  versions of the Rust nightly built with them (`containers/rapx/REFERENCES.md`);
  both are in the 3-day rule.
- **NVIDIA's driver and Container Toolkit, in `bootc/fedora-coreos/Containerfile`:**
  two custom managers on the `rpm` datasource, read from each repository's
  `repodata/`; the driver stays on one branch (`allowedVersions`), and
  neither is automerged (CI runs no GPU:
  `bootc/fedora-coreos/REFERENCES.md`, "GPU image").
- **Renovate's image, one version:** `renovate.yml`'s `extract` job
  and the validator of `AGENTS.md`'s checks. The workflow holds it in
  `RENOVATE_VERSION`, after a `# renovate:` comment: the shared preset's
  manager for workflow versions reads it.
- **Renovate's image in a nightly window, before 5am:** it releases
  several times a day, each release its own merged PR. The window is 5
  hours: Mend's hosted Renovate runs every 4 hours, and also on pushes,
  so a release during the window after the first merge opens a second
  PR. A release age can't space them: ghcr.io gives no release date
  (above).
- **Debian snapshot group in the same window, on Saturday:** a new
  snapshot comes every few hours, so all of Saturday merged several.
  Nor is an open PR updated outside the window (`updateNotScheduled`):
  it waits for CI and merges as proposed. Every rule of the group
  carries the schedule: the group is one branch.
- **Automerged once CI passes:** actions (grouped), and minor and patch
  releases of what CI exercises (build tools, Renovate, applications
  with a server test) or the docs only use (hadolint). Each
  image's `AGENTS.md` says which.
- **By hand:** base images, image-builder-cli, every major release, and
  the images whose `AGENTS.md` says so. A new base major or Kubernetes
  minor changes the tag: hosts stay on the old, no longer rebuilt, until
  `bootc switch`.

## `copilot-fix.yml`

A Renovate PR whose build fails waits for a person, automerged or not.
Copilot's cloud agent gets the first attempt.

- **An `@copilot` comment on the PR, not an issue assigned to Copilot:**
  Copilot pushes to the PR's branch, so the fix lands in the PR that
  failed; from an issue it opens a second PR.
- **Triggered by `workflow_run`, not a Copilot automation:** automations
  have no "build failed" trigger, and live outside the repository.
- **`COPILOT_FIX_TOKEN`:** Copilot answers the mentions of users with
  write access (`troubleshoot-cloud-agent.md`); `GITHUB_TOKEN` writes as
  `github-actions[bot]`. A fine-grained token of such a user, with a
  Copilot plan: this repository only, *Pull requests: read and write*.
- **Once per PR:** a fix that fails again goes to a person, rather than
  Copilot answering its own failures.
- **The comment points Copilot to every `AGENTS.md` above the files it
  changes:** for Copilot the nearest one takes precedence
  (`data/reusables/copilot/custom-instructions-agents.md`), and an
  image's rules start at the root's.
- **A person merges the fix:** CI runs on Copilot's pushes once someone
  with write access approves the run. The workflow disables the PR's
  GitHub auto-merge, which Renovate enables only when it commits
  (`reattemptPlatformAutomerge`), and Renovate's own merge skips a
  branch it didn't write alone (`isBranchModified`,
  `lib/workers/repository/update/pr/automerge.ts`).
