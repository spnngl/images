# cinny

Cinny (a Matrix web client) built from source: upstream's static web
app, served by static-web-server (SWS), one static musl binary, on
`scratch`. Upstream serves it with nginx; the app is at `/app`, as in
upstream's image. Runtime contract: the Containerfile's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The app build is upstream's release build (its `Dockerfile`, the deploy
  workflow): `npm ci`, `npm run build`. Node's major is upstream's
  `.node-version`. `--ignore-scripts` stays: `canvas`' install script
  downloads an unverified binary. When a build needs a script, `npm
  rebuild <package>` for that one, and say why in `REFERENCES.md`.
- The server is built with its default features, static, as UID 65532
  (cache ids end in `-65532`).
- Unknown paths answer `index.html`, 200: SWS' fallback has no per-path
  rule, so a missing `/assets/*` is not a 404 (nginx's behaviour).
  Accepted, pinned by the smoke test.
- **No `Cache-Control`, no security headers**: `sw.js` and the other
  unhashed files must not outlive a release; `X-Frame-Options: DENY`
  breaks Element Call, framed from the same origin.
- **Precompressed copies**: the build writes `.br` and `.gz` beside each
  text asset; SWS sends them as they are when `SERVER_COMPRESSION_STATIC`
  is true (its default is false). Never beside the root
  `config.json`: they would hide a mounted one. A new top-level file
  users may replace takes the same exception.
- Probe: `GET /health`.
- The final stage copies the app from `frontend-files`, the stage that
  puts the app's npm packages in the SBOM: BuildKit scans no stage the
  target doesn't depend on.

## Smoke test

The build stage runs it (`scratch` has no shell): `--version`, then the
server with the built app, asked for `/health`, `/`, a deep link,
`config.json`, `sw.js`, a bundle and its Brotli copy, the crypto
`.wasm` (`application/wasm`), Element Call's page (no
`X-Frame-Options`), a missing file (falls back), the request log, and
a clean SIGTERM stop.

## Updates

Renovate follows both GitHub tags, stable releases only. Minor and
patch releases of both, and Node and Rust minor bumps, are automerged
(the smoke test covers the files and headers, not a login); a major
release is never. Before merging a Cinny release read
upstream's `Dockerfile`, `.node-version`, `docker-nginx.conf`,
`vite.config.js` and `config.json` at the new tag: a new route or file
nginx treats apart, a new top-level file users replace, a new Node
major, a new install script (`npm ci --ignore-scripts`). For SWS, read
its `CHANGELOG.md` for changed `SERVER_*` variables.
