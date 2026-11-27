# speculaire

Spéculaire (node agent: registry mirror, peer-to-peer blob sharing, NRI
image-verification gate, Rust) built from source at a commit of `main`,
no patch, one static-PIE musl binary on `scratch`. The binary is
upstream's release build, byte for byte. A drop-in for upstream's
`packaging/Containerfile` image in its DaemonSet: same path
(`/usr/bin/speculaire`), entrypoint and user. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Root, with no capability: no `USER` line.
- `ENTRYPOINT ["/usr/bin/speculaire"]` and no `CMD`.
- The build stage's image is upstream's (`build/Containerfile`): same
  tag; the binary is upstream's byte for byte while the digests match
  too. Its toolchain is the one `rust-toolchain.toml` pins, checked by
  the build.
- `SOURCE_DATE_EPOCH=0` and `CARGO_TARGET_DIR=/target` on the cargo
  build, as upstream's: they keep the binary upstream's byte for byte.
- The build stage compiles as UID 65532.

## Tests

The build stage runs `just musl`'s checks (static-PIE, the
cargo-auditable section), the version line, and `configure` on a
containerd config in `/tmp`, as the init container runs it. Neither the
agent nor `check-config` runs: both need a runtime's socket. Upstream's
own tests run in upstream's CI, on the same commit.

Once pushed, signed and attested, `verify.sh` runs `speculaire verify`
from the list on itself under `policy.yaml` (bake-push; upstream
D199): it prints `allow` and exits 0. By hand, on a pushed digest:
`containers/speculaire/verify.sh ghcr.io/spnngl/images/speculaire@<digest>`.
`policy.yaml` names `build-apps.yml` at `refs/heads/main`: a rename
of the workflow, or a push from another branch, fails the check until
the policy follows.

## Updates

Never automerged; proposed on Saturday (`renovate.json5`). Every update
is checksum-only: a new commit of `main`. Before merging it, read
upstream's changes from the PR's link, checking:

- `rust-toolchain.toml`: a new toolchain fails the build. Set the rust
  entry of `docker-bake.hcl` to upstream's `build/Containerfile` build
  stage (tag, digest), with its `depName` and `extractVersion`.
- `build/Containerfile` and `justfile` (`musl` recipe): a new build
  package, flag or check goes in the build stage.
- `packaging/Containerfile`, `packaging/speculaire.service`: a new
  path, port or file the image needs goes in the header.

The rust digest moves with the base digests, automerged on Saturday.

After upstream's first release, follow its tags: in `docker-bake.hcl`,
`datasource=github-tags depName=spnngl/speculaire
extractVersion=^v(?<version>.+)$`, `version` the release and `checksum`
its commit, `BASE_VERSION = base.version`, tags the version; drop
`spnngl/speculaire` from the weekly rule of `renovate.json5` and from
`.github/AGENTS.md`.
