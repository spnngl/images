# zot

zot (OCI-native container image registry, Go) on `scratch`. Runtime
contract: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Build with `make binary`, as upstream releases: set only
  `BUILDMODE_FLAGS`, `ZUI_BUILD_PATH`, `COMMIT` and `RELEASE_TAG`.
- The UI is zui at the tag `ZUI_VERSION` names in zot's `Makefile`; the
  build fails on any other.
- `config.json` is upstream's (`build/stacker.yaml`) with log level
  `info` and no `mgmt`.
- `/tmp` stays in the image, mode 1777: Trivy writes its scan files
  there, and a tmpfs mounted over it takes that mode.
- Probes: `GET /livez`, `/readyz` and `/startupz` on 5000.

## Tests

The build stage's smoke test (its comment lists what it checks), and
`zot --version` in the final stage, on each platform.

## Updates

Renovate follows zot's stable tags and automerges minor and patch
releases on the smoke test. Major releases wait: read what changed
(`https://github.com/project-zot/zot/compare/v<old>...v<new>`) and back
up `/var/lib/registry` first. On a `ZUI_VERSION` change in zot's
`Makefile`, the build fails at its check: set `zui` in
`docker-bake.hcl` to the new tag and its commit. Check the build
against the `binary` target of the `Makefile`, and `config.json`
against `build/stacker.yaml`. A checksum-only update means upstream
moved a tag.
