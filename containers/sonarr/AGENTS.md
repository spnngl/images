# sonarr

Sonarr, the TV series manager of the *arr apps: upstream's
self-contained release archive (.NET, glibc) on distroless'
`cc-debian13`, with the Debian packages they need that distroless lacks
(`libicu76`, `libsqlite3-0`), copied with their dpkg status.
The archive's ffprobe (a static binary) stays. Runtime contract: the
Containerfile's header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **Upstream's release archive, not a build:** `docker-bake.hcl` holds
  one version and one sha256 per platform (`base`, `base_arm64`), both
  at the same release: the build fails on two versions, and one
  Renovate PR moves both.
- **The built-in updater stays off:** the program lives in a folder
  named `bin` with `package_info` (`UpdateMethod=Docker`) beside it:
  Sonarr reads that file only then (`DeploymentInfoProvider.cs`).
  `Sonarr.Update/` is not shipped.
- **Analytics and .NET diagnostics off by `ENV`**, in both stages: the
  server test runs under the final image's settings.
- **A runtime package** (a library the archive loads that distroless
  lacks) is in the Containerfile's package loop and installed in the
  build stage, which the server test then runs on. Sonarr loads the
  system's `libsqlite3.so.0` (`AssemblyLoader.cs`), hence `libsqlite3-0`.
- **Credentials from the runtime:** the API key and the PostgreSQL
  settings come as `Sonarr__<Section>__<Key>` variables; the image
  holds none.
- **Done when** the build passes: the build stage checks the archive's
  sha256, starts the server on a throwaway data folder with a random API
  key, finds `/ping` answering and the API reporting `${BASE_VERSION}`,
  writes a tag and reads it back (database migrations, SQLite), and
  stops it with SIGTERM; the final image runs ffprobe and Sonarr's
  help mode (its libraries, ICU included) and has no `/bin/sh`
  (`docker create`, then `docker export | tar -t`).

## Updates

Renovate takes each release from the apps' update feed (custom
datasource `servarr`, `renovate.json5`), three days after its release,
with the sha256 of both archives; minor and patch releases automerge
when the build passes, majors by hand after the release notes:
<https://github.com/Sonarr/Sonarr/releases>. The server test leaves
out searches and downloads, which need the network and an indexer.

On a failing build, compare with the new archive: the files `rm` removes
in the Containerfile (a renamed one fails the build), the `readelf -d`
`NEEDED` libraries of its `.so` files (a new one joins the package loop
unless distroless has it), the `package_info` keys with
`DeploymentInfoProvider.cs`, `AnalyticsEnabled` with `LogOptions.cs`.
When updates stop coming, compare the feed's URL and fields with
`UpdatePackageProvider.cs`: the feed answers for the `version` the client
sends (`docker-bake.hcl` explains the one it sends).
