# CI and updates

Workflows in `workflows/`; `renovate.json5` at the repository root.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

- `build-bootc.yml`: lint, build, sign and push every bootc image of its
  matrix, each platform on its own runner.
- `build-apps.yml`: the same for the application images that changed,
  found in the Bake files, not listed. Its `gate` job is the check the
  `main` ruleset requires: its `needs` lists every job a pull request
  runs.
- `actions/bake-*`: the composite actions the build workflows share (see
  "Bake workflows").
- `renovate.yml`: validates `renovate.json5`, and that Renovate reads
  every `# renovate:` comment of the Bake files.
- `copilot-fix.yml`: asks Copilot, once per pull request, to fix a
  Renovate branch whose build failed.
- The other workflows call the shared ones of `github.com/spnngl/.github`.

## Bake workflows

A workflow that builds Bake targets has these jobs, each running one
action; a Bake file describes the build, the workflow only runs it.

1. `discover` (`actions/bake-discover`) lists the targets that changed in
   the Bake files, as JSON. A job that calls a local action checks out
   first.
2. `build` (`actions/bake-build`) builds one target on one platform, on
   a runner of that platform. It pushes the image by digest, untagged,
   or, without `push`, writes an OCI layout to scan or test.
3. `push` (`actions/bake-push`) merges the platforms into one manifest
   list with every tag, then signs, verifies and attests it.

Rules of the actions, so a workflow stays a list of `uses:`:

- A Bake target carries what its image is (context, Containerfile,
  arguments, tags, entitlements); the workflow passes only what CI
  decides: the platform, the cache, the output, `SOURCE_DATE_EPOCH`.
- `bake-discover` rebuilds a target when its resolved definition changed,
  or a file its context keeps changed (its `.dockerignore`), or the
  workflow or an action changed.
- An image is pushed once, by digest, in `build`; `push` only adds tags.
  Never export one build twice (an OCI layout beside the push): the
  digest bake reports is then not the pushed one.
- A new action input has a default or a reason in `REFERENCES.md`.

## Rules

- Runners are `ubuntu-26.04` and `ubuntu-26.04-arm`: `COPY --link`
  needs buildah 1.41+.
- Values derived from a pinned version are rewritten with it, in the
  same Renovate replacement (`autoReplaceStringTemplate`).
- An application image needs no `renovate.json5` entry
  (`containers/AGENTS.md`, "Versions"); its PRs point to the *Updates*
  section of its `AGENTS.md`. Exceptions: a group for versions that
  must move in one PR (`nzbget`, `flux-aio`, `fluffychat`, `rapx`); a weekly schedule for a
  branch pinned to a commit (`crowdsecurity/hub`, `Silo-Server/silo-server`).
  A bootc image has a
  `packageRules` entry, with `prBodyNotes`.
- Vulnerability false positives go in `.grype.yaml` and
  `.trivyignore.yaml`, each with its reason.
- Application images' registries live in `tags()`
  (`containers/docker-bake.hcl`), ghcr.io first: `bake-build` pushes
  and `bake-push` attests there (`repositories[0]`); `bake-push` signs
  in every registry but Docker Hub. A new registry
  also needs its login in `bake-push` and, if signed, a scope in the
  hosts' signature policy: every
  `bootc/*/sysroot/*/etc/containers/policy.json` (fedora-coreos's in
  `sysroot/system/`), the `$scopes` of both `policy.jq` (`bootc/fedora/`,
  `bootc/fedora-coreos/`), both `registries.d/spnngl-images.yaml`.
