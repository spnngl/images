# mjolnir

Mjolnir (a Matrix moderation bot) built from source: upstream's
TypeScript build, run by Node.js on distroless' `nodejs22-debian13`, its
two native addons from pins. The app is at `/mjolnir`, its state on the
`/data` volume, as in upstream's image. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- The build is upstream's release build (its `Dockerfile`): `yarn
  install --frozen-lockfile`, `yarn build`. Node's major is upstream's
  `engines.node`, on both `FROM` lines (build stage and distroless
  `nodejs<major>`): change them together, by hand.
- `--ignore-scripts` stays. The two native addons come from the pins of
  `docker-bake.hcl`: `@tensorflow/tfjs-node`'s binding, built from source
  against the pinned libtensorflow; `@matrix-org/matrix-sdk-crypto-nodejs`'
  addon, its GitHub release's. The pin check (the `/app` step) fails the
  build when a pin differs from upstream's, and names the pin. When
  another package needs a script, build or pin it, and say why in
  `REFERENCES.md`.
- The image ships what the bot runs: the build's `lib/`, the production
  `node_modules` and `package.json`, in `/mjolnir`, root-owned. `/data`
  is empty and 65532's. The test (below) runs on the same tree.
- Built and tested as UID 65532 (cache ids end in `-65532`).
- Probe: `GET /healthz` on 8080, once the config turns on
  `health.healthz`.

## Smoke test

The build stage runs it, on the shipped tree: the bot starts on a test
`production.yaml` read from `NODE_CONFIG_DIR`, loads both addons,
creates its `dataPath` and stops at the refused homeserver with
upstream's `Failed to setup mjolnir from the config`; nsfwjs' bundled
model classifies on tfjs-node's TensorFlow backend; the crypto addon
opens an `OlmMachine` on SQLite. The final stage's last `RUN` loads both
addons against distroless' libraries and checks its Node against
`engines.node`.

## Updates

Renovate follows GitHub tags, stable releases only. Minor and patch
releases are automerged (the test starts on an empty `/data`: a release
changing the stored state needs reading); a major release is never.

Renovate lists new releases of the pinned addons (tfjs-node on npm, the
crypto addon on GitHub) on its Dependency Dashboard, awaiting approval:
the notice of what upstream will need. An approved PR stays red until
upstream's `yarn.lock` has that version. A red pin check on a Mjolnir PR
means upstream moved: set the pins to upstream's, in that PR.

- `tfjs_node.version`: `yarn.lock`'s. At that version, in tfjs-node's
  `scripts/`: `libtensorflow_amd64.version` is `LIBTENSORFLOW_VERSION`
  (`deps-constants.js`), `libtensorflow_arm64.version` the `<x>.<y>` of
  the archive `tf-builds/libtensorflow_r<x>_<y>_linux_arm64.tar.gz`
  (`install.js`). Each `checksum` is the
  archive's sha256 (`curl -fsSL <url> | sha256sum`, the URLs of the
  Containerfile's `natives` stages): Google publishes none.
- `matrix_sdk_crypto`: both entries at `yarn.lock`'s version (`v`
  prefix), each `checksum` the sha256 of its release asset (GitHub's
  digest).

Before merging read upstream's `Dockerfile`, `package.json` (`engines`,
`scripts`) and the install scripts new to `yarn.lock` at the new tag.
