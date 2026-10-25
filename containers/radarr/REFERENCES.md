# radarr: references

The shape, and every decision not listed here, are `containers/prowlarr`'s
(its REFERENCES.md): Radarr is built from the same upstream codebase, with
the same archive layout, `package_info`, environment settings, tests and
update feed. Below: what differs.

## Sources

- Upstream: `github.com/Radarr/Radarr` at tag `v<BASE_VERSION>`, the files
  `containers/prowlarr/REFERENCES.md` names (`DeploymentInfoProvider.cs`,
  `Bootstrap.cs`, `UpdatePackageProvider.cs`)
- Releases: <https://github.com/Radarr/Radarr/releases>, the archives
  `Radarr.master.<BASE_VERSION>.linux-core-<x64|arm64>.tar.gz`
- Update feed: `https://radarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=<x64|arm64>`

## Decisions

- **Port 7878, API `/api/v3/`, `Radarr__<Section>__<Key>`** settings
  (`Bootstrap.cs`: `Radarr:Postgres`, `:App`, `:Auth`, `:Server`, `:Log`,
  `:Update`); the server test's status and tag calls use the API path.
- **Analytics off (`Radarr__Log__AnalyticsEnabled=false`):** upstream's
  default is on (`LogOptions.AnalyticsEnabled`).
- **The license file is `LICENSE`** in the archive; GPL-3.0-only as
  Prowlarr's: the text is GPL v3 and the API's metadata says `GPL-3.0`.
- **ffprobe stays:** the archive's static `ffprobe`, next to the program,
  is the tool Radarr runs for media information (the updater sets its
  executable flag: `InstallUpdateService.cs`); the final image runs
  `ffprobe -version`. SQLite is bundled (`libe_sqlite3.so`, libc only).
