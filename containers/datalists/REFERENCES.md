# datalists: references

## Sources

- GeoLite2: `github.com/P3TERX/GeoLite.mmdb`,
  `.github/workflows/GeoLite.yml` (MaxMind's databases every 3 days, the
  last 2 releases kept); Renovate's `github-release-attachments`
  datasource (`lib/modules/datasource/github-release-attachments`: the
  digest of each file)
- Cloudflare's IP ranges: <https://www.cloudflare.com/ips/>
  (`ips-v4`, `ips-v6`)
- ipverse's prefixes (CC0), the release tagged `latest`, rebuilt daily:
  `github.com/ipverse/as-ip-blocks` (by AS),
  `github.com/ipverse/country-ip-blocks` (by country); a lookup:
  <https://lens.ipverse.net>

## Decisions

- **An image of its own:** the lists change every few days, the images
  using them less often; a rebuild of the lists alone, and a digest
  update per image using them (Renovate), instead of each image
  fetching them.
- **At the root:** a `COPY --from` or an image volume puts them where
  its image needs them (haproxy: `/data/lists`).
- **One layer per source** (a `COPY --link` of a stage each), the one
  changing least first: Cloudflare's, then GeoLite2, then ipverse's
  (as/, then country/). A layer's digest depends only on its files
  (`--link`; CI's `rewrite-timestamp` clamps their times), so a rebuild
  pushes only the changed ones.
- **Tagged `latest` only:** no one version names the lists (GeoLite2's
  is a date, the others have none); the users pin the digest.
- **No `debian` matrix, no Debian argument:** the image has no Debian
  file; Debian trixie only runs the check, with no package to install.
- **GeoLite2 from P3TERX, pinned:** MaxMind's own downloads need a
  license key, a build secret. Its releases are deleted within about 6
  days, so Renovate takes each one at once and automerges it, its
  `--checksum` the sha256 Renovate computes (the regex manager's
  `currentDigest`): one entry per file, one PR for the three
  (`groupName`). Renovate reads the pinned release to find each file's
  new digest: once it is deleted, only a manual update fixes the build
  (AGENTS.md, Updates). Redistributing GeoLite2 in a public image:
  accepted by the owner, MaxMind's license notwithstanding (label
  `LicenseRef-GeoLite2-EULA`).
- **Cloudflare's and ipverse's lists, not pinned:** Cloudflare's have no
  version, ipverse's `latest` is replaced each day; BuildKit fetches
  them again when they change, so a build, and the weekly rebuild, has
  the current ones. amd64 and arm64 fetch them each: a release between
  the two builds gives them different lists, until the next build.
- **ipverse's unpacked in the `check` stage:** copying them from there
  makes the check run (a build only runs the stages the final one
  uses), and the `COPY --chmod` sets their modes, which `ADD --unpack`
  keeps from the archives.
- **The check, the lists' format only:** lookups are haproxy's smoke
  test, which gates its digest update; the files it loads are the ones
  checked not empty.
