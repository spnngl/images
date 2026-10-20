# CI and updates

Workflows in `workflows/`; `renovate.json5` at the repository root.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

- `build-bootc.yml`: lint, build, sign and push every bootc image of its
  matrix, each platform on its own runner.
- `build-apps.yml`: the same for the application images that changed,
  found in the Bake files, not listed. Its `gate` job is the check the
  `main` ruleset requires: its `needs` lists every job a pull request
  runs.
- `renovate.yml`: validates `renovate.json5`, and that Renovate reads
  every `# renovate:` comment of the Bake files.
- `copilot-fix.yml`: asks Copilot, once per pull request, to fix a
  Renovate branch whose build failed.
- The other workflows call the shared ones of `github.com/spnngl/.github`.

## Rules

- Runners are `ubuntu-26.04` and `ubuntu-26.04-arm`: `COPY --link`
  needs buildah 1.41+.
- Values derived from a pinned version are rewritten with it, in the
  same Renovate replacement (`autoReplaceStringTemplate`).
- An application image needs no `renovate.json5` entry
  (`containers/AGENTS.md`, "Versions"); its PRs point to the *Updates*
  section of its `AGENTS.md`. A bootc image has a `packageRules` entry,
  with `prBodyNotes`.
- Vulnerability false positives go in `.grype.yaml` and
  `.trivyignore.yaml`, each with its reason.
- Application images' registries live in `tags()`
  (`containers/docker-bake.hcl`), ghcr.io first: `build-apps.yml`
  builds, scans, logs in and attests there (`repositories[0]`); its
  `push` job signs in every registry but Docker Hub. A new registry
  also needs its login in that job and, if signed, a scope in the
  hosts' signature policy: every
  `bootc/*/sysroot/*/etc/containers/policy.json`, `policy.jq`'s
  `$scopes`, `registries.d/spnngl-images.yaml`.
