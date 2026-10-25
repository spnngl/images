# seerr

Seerr (a media request manager) built from source: upstream's Express
server and Next.js app, run by Node.js on distroless'
`nodejs22-debian13`. The app is at `/app`, as in upstream's image.
Runtime contract: the Containerfile's header. Upstream sources and the
reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The build is upstream's release build (its `Dockerfile`): `pnpm
  install --frozen-lockfile`, `pnpm build`. Node's major is upstream's
  `engines.node`, on both `FROM` lines (build stage and distroless
  `nodejs<major>`): change them together, by hand. pnpm is upstream's
  `packageManager`, through corepack.
- `--ignore-scripts` stays. `sqlite3` is the one package built from
  source (`node-gyp rebuild`, npm's node-gyp): its script downloads an
  unverified binary. When another package needs a script, rebuild that
  one, and say why in `REFERENCES.md`.
- The image ships what the server reads at run time (`dist`, `.next`,
  the production `node_modules`, `public`, `package.json`,
  `seerr-api.yml`, `committag.json`, `next.config.ts`), root-owned. The
  two volumes, `/app/config` and `/app/.next/cache`, are 65532's.
  A file the server starts to read goes in `app-files`; the test (below)
  runs on the same tree and fails when one is missing.
- Built and tested as UID 65532 (cache ids end in `-65532`).
- Probe: `GET /api/v1/status/appdata` (no login, no database, no
  outbound call). Not `/api/v1/status`: it queries GitHub without a
  timeout and hangs when egress is blocked.

## Smoke test

The build stage runs it, on the pruned production tree: the server on
loopback with a temp config folder; `/api/v1/status` reports
`<BASE_VERSION>`; `/_next/image` answers a WebP (`sharp`); the image
proxy accepts upstream's hosts (`next.config.ts` is read); `/` answers;
`bcrypt` and `sqlite3` work. The final stage's last `RUN` loads the
three addons against distroless' libraries and checks its Node against
`engines.node`.

## Updates

Renovate follows GitHub tags, stable releases only. Minor and patch
releases are automerged (the test starts a new database, it does not
migrate the previous release's: read the release notes of a version
that changes `server/migration`); a major release is never. Before
merging read upstream's `Dockerfile`, `package.json` (`engines`,
`packageManager`, `pnpm.onlyBuiltDependencies`, the lifecycle scripts)
and `next.config.ts` at the new tag: a new Node major, a new install
script, a new file the server reads.
