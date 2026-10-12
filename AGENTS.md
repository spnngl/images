# Agent guide

Two kinds of image, each with its own guide. Before changing a file
under one folder, read its guide:

- `bootc/`: bootable OS images, built with podman:
  [bootc/AGENTS.md](bootc/AGENTS.md)
- `containers/`: application images, built with `docker buildx`:
  [containers/AGENTS.md](containers/AGENTS.md)

[ARCHITECTURE.md](ARCHITECTURE.md) holds the design and the reason for
each choice. Before a change, read the sections it touches:

- an image: its own section, "Design decisions" and "Known limits"
- `.github/workflows/`: "CI: ..." and "Vulnerability scanning"
- `renovate.json5`, or a pinned version: "Updates"

## Sources of truth

Read upstream's source at the version this repository pins
(`git_clone`). Each image's ARCHITECTURE.md section names its upstream.

Renovate: `github.com/renovatebot/renovate` (`docs/usage`, managers in
`lib/modules/manager`, presets in `lib/config/presets/internal`).

## Every image

- **Pinned versions** (image tag, release, checksum) are each tracked by
  `renovate.json5`. The dockerfile manager reads `FROM` and `# syntax=`;
  anything else needs a custom manager matching every place it is
  written, under one dependency name. Write a version only where
  Renovate updates it; docs and comments say `<BASE_VERSION>`.
- **Credentials** come from the runtime. Images hold no user, password,
  key or pull secret.
- **Containerfiles** pass `hadolint` (`.hadolint.yaml`). Ignore a
  finding only with a comment saying why.
- **Comments** give the *why* of every significant step, with a doc link
  when useful.

## Scripts

- Bash, `set -euo pipefail`; they `cd` to the repo root, so they run
  from any folder.
- Requirements checked first, each failure naming the command that fixes
  it.

## Checks

```sh
git ls-files -z '*.sh' | xargs -0 shellcheck
docker run --rm -v "${PWD}:/w:ro" -w /w docker.io/hadolint/hadolint:v2.15.1 hadolint bootc/*/Containerfile containers/*/Containerfile
docker run --rm -v "${PWD}:/w:ro" -w /w ghcr.io/renovatebot/renovate:44.151.2 renovate-config-validator --strict
```

Then the build check of the image's guide. Report each check as run or
not run, with its result.

## Commits

Conventional Commits: `<type>(<scope>): <summary>`, with a body
explaining why.
