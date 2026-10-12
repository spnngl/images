# Agent guide

[ARCHITECTURE.md](ARCHITECTURE.md) gives the overall design. Before
changing a file, read the `AGENTS.md` of every folder above it, up to
the image's own:

- `bootc/`: bootable OS images, built with podman:
  [bootc/AGENTS.md](bootc/AGENTS.md)
- `containers/`: application images, built with `docker buildx`:
  [containers/AGENTS.md](containers/AGENTS.md)
- `.github/`, `renovate.json5`, or a pinned version:
  [.github/AGENTS.md](.github/AGENTS.md)

Beside each image's `AGENTS.md`, and `bootc/`'s and `.github/`'s, a
`REFERENCES.md` names the upstream sources and gives the reason for
each decision. Read upstream's source at the version this repository
pins (`git_clone`). A changed decision updates its reason there.

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
