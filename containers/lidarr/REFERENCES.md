# lidarr: references

The shape, and every decision not listed here, are `containers/prowlarr`'s
(its REFERENCES.md): Lidarr is built from the same upstream codebase, with
the same archive layout, `package_info`, environment settings, tests and
update feed. Below: what differs.

## Sources

- Upstream: `github.com/Lidarr/Lidarr` at tag `v<BASE_VERSION>`, the files
  `containers/prowlarr/REFERENCES.md` names (`DeploymentInfoProvider.cs`,
  `Bootstrap.cs`, `UpdatePackageProvider.cs`)
- Releases: <https://github.com/Lidarr/Lidarr/releases>, the archives
  `Lidarr.master.<BASE_VERSION>.linux-core-<x64|arm64>.tar.gz`
- Update feed: `https://lidarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=<x64|arm64>`

## Decisions

- **Port 8686, API `/api/v1/`, `Lidarr__<Section>__<Key>`** settings
  (`Bootstrap.cs`: `Lidarr:Postgres`, `:App`, `:Auth`, `:Server`, `:Log`,
  `:Update`); the server test's status and tag calls use the API path.
- **Analytics off (`Lidarr__Log__AnalyticsEnabled=false`):** upstream's
  default is on (`LogOptions.AnalyticsEnabled`).
- **The license file is `LICENSE.md`** in the archive; GPL-3.0-only as
  Prowlarr's: the text is GPL v3 and the API's metadata says `GPL-3.0`.
- **fpcalc stays:** the archive's static `fpcalc` (Chromaprint), next to
  the program, fingerprints audio (`FpcalcCheck.cs` warns when it is
  missing); the final image runs `fpcalc -version`. SQLite is bundled
  (`libe_sqlite3.so`, libc only).
