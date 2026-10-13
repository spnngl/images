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
  Renovate. The dockerfile manager reads `FROM` and `# syntax=`; an
  application image's versions are in its `docker-bake.hcl`, each after
  a `# renovate:` comment (`containers/AGENTS.md`); anything else needs a
  custom manager in `renovate.json5` matching every place it is written,
  under one dependency name. Write a version only where Renovate updates
  it; docs and comments say `<BASE_VERSION>`.
- **Credentials** come from the runtime: no user, password, key or pull
  secret in an image.
- **Containerfiles** pass `hadolint` (`.hadolint.yaml`); each ignore
  carries a comment giving its reason.
- **Comments** give the *why* of every significant step, with a doc link
  when useful.

## Scripts

Bash, `set -euo pipefail`, `cd` to the repo root (they run from any
folder). Requirements are checked first, each failure naming the command
that fixes it.

## Checks

```sh
git ls-files -z '*.sh' | xargs -0 shellcheck
docker run --rm -v "${PWD}:/w:ro" -w /w docker.io/hadolint/hadolint:v2.15.1 hadolint bootc/*/Containerfile containers/*/Containerfile
docker run --rm -v "${PWD}:/w:ro" -w /w ghcr.io/renovatebot/renovate:44.155.2 renovate-config-validator --strict
f=(-f containers/docker-bake.hcl); for x in containers/*/docker-bake.hcl; do f+=(-f "${x}"); done; docker buildx bake "${f[@]}" --print '*' > /dev/null
```

Then the build check of the image's guide. Report each check as run or
not run, with its result.

## Commits

Conventional Commits: `<type>(<scope>): <summary>`, with a body
explaining why.
