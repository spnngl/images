# sonarr: references

The shape, and every decision not listed here, are `containers/prowlarr`'s
(its REFERENCES.md): Sonarr is built from the same upstream codebase, with
the same archive layout, `package_info`, environment settings, tests and
update feed. Below: what differs.

## Sources

- Upstream: `github.com/Sonarr/Sonarr` at tag `v<BASE_VERSION>`, the files
  `containers/prowlarr/REFERENCES.md` names (`DeploymentInfoProvider.cs`,
  `Bootstrap.cs`, `UpdatePackageProvider.cs`)
- Releases: <https://github.com/Sonarr/Sonarr/releases>, the archives
  `Sonarr.main.<BASE_VERSION>.linux-<x64|arm64>.tar.gz`
- Update feed: `https://services.sonarr.tv/v1/update/main/changes?version=4.0.0.0&os=linux&runtime=netcore&includeMajorVersion=true&arch=<x64|arm64>`

## Decisions

- **Port 8989, API `/api/v3/`, `Sonarr__<Section>__<Key>`** settings
  (`Bootstrap.cs`: `Sonarr:Postgres`, `:App`, `:Auth`, `:Server`, `:Log`,
  `:Update`); the server test's status and tag calls use the API path.
- **Analytics off (`Sonarr__Log__AnalyticsEnabled=false`):** upstream's
  default is on (`LogOptions.AnalyticsEnabled`).
- **The license file is `LICENSE.md`** in the archive; GPL-3.0-only as
  Prowlarr's: the text is GPL v3 and the API's metadata says `GPL-3.0`.
- **`libsqlite3-0`, copied with `libicu76`:** Sonarr's SQLite binding
  (`System.Data.SQLite.Core.Servarr`) loads the system's `libsqlite3.so.0`
  and bundles no native library (`src/NzbDrone.Common/Composition/AssemblyLoader.cs`,
  `src/NzbDrone.Core/Datastore/DbFactory.cs`; upstream's deb and Docker
  build install `sqlite3`). Its only dependency, `libc6`, is distroless'.
- **ffprobe stays:** the archive's static `ffprobe`, next to the program,
  is the tool Sonarr runs for media information (the updater sets its
  executable flag: `InstallUpdateService.cs`); the final image runs
  `ffprobe -version`. `mediainfo`, which upstream's Docker build installs,
  is not used by v4.
- **The feed needs a `version` parameter:** without it the feed answers
  for a 3.x install (the newest it lists is 4.0.9.2244, the last release
  3.x can update to), and the 4.x releases are missing. `version=4.0.0.0`
  lists them, `includeMajorVersion=true` is what Sonarr's updater asks.
  Checked: x64 and arm64 hashes equal GitHub's asset digests.
