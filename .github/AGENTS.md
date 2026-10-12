# CI and updates

Workflows in `workflows/`; `renovate.json5` at the repository root.
Sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

- `build-bootc.yml`: lint, build, sign and push every bootc image of its
  matrix, each platform on its own runner.
- `build-apps.yml`: the same for the application images that changed,
  found, not listed.
- `shellcheck.yml`: every script.
- The other workflows call the shared ones of `github.com/spnngl/.github`.

## Rules

- Runners are `ubuntu-26.04` and `ubuntu-26.04-arm`: `COPY --link`
  needs buildah 1.41+.
- Values derived from a pinned version are rewritten with it, in the
  same Renovate replacement (`autoReplaceStringTemplate`).
- A `packageRules` entry per image says automerged, or what to check by
  hand (`prBodyNotes`); the image's `AGENTS.md` says why.
- Vulnerability false positives go in `.grype.yaml` and
  `.trivyignore.yaml`, each with its reason.
