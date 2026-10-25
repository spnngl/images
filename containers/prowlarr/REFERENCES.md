# prowlarr: references

## Sources

- Upstream: `github.com/Prowlarr/Prowlarr` at tag `v<BASE_VERSION>`:
  `src/NzbDrone.Core/Configuration/DeploymentInfoProvider.cs`
  (`package_info`), `src/NzbDrone.Common/Options/` (settings by
  environment), `src/NzbDrone.Host/Bootstrap.cs`
  (`AddEnvironmentVariables`), `src/NzbDrone.Host/ApplicationModes.cs`,
  `src/NzbDrone.Common/EnvironmentInfo/StartupContext.cs` (`-nobrowser`,
  `-data`, `-?`), `src/NzbDrone.Core/Update/UpdatePackageProvider.cs`
  (the update feed), `src/Prowlarr.Http/Ping/PingController.cs`
- Releases: <https://github.com/Prowlarr/Prowlarr/releases>, the archives
  `Prowlarr.master.<BASE_VERSION>.linux-core-<x64|arm64>.tar.gz`
- Update feed:
  `https://prowlarr.servarr.com/v1/update/master/changes?os=linux&runtime=netcore&arch=<x64|arm64>`
- `containers/haproxy` (distroless shape, package loop),
  `containers/flux-toolbox` (a release archive per platform),
  `renovate.json5`'s `debian-snapshot` (a custom datasource)
- Distroless: `github.com/GoogleContainerTools/distroless`, `cc/` and
  `base/` (what `cc-debian13` holds, `/var/lib/dpkg/status.d`)
- Renovate: `lib/modules/datasource/custom/` (`schema.ts`: `digest`,
  `releaseTimestamp`, `sourceUrl`), `lib/modules/datasource/github-release-attachments/index.ts`

## Decisions

- **Upstream's release archive, not a build:** a source build fetches the
  .NET SDK and every NuGet package unpinned: trixie has no .NET SDK and
  upstream has no `packages.lock.json` (jellyfin's reason).
- **Distroless `cc-debian13`, not Dalec:** the archive's libraries link
  glibc, libstdc++, libgcc and zlib (`readelf -d` of every `.so`, both
  platforms: the same), and .NET dlopens OpenSSL and ICU. Distroless has
  all but ICU (`libicu76`), which the build stage's package loop copies
  with its dpkg status. SQLite (`libe_sqlite3.so`) and
  `libMonoPosixHelper.so` need libc only. `libgssapi-krb5-2`, which
  `libSystem.Net.Security.Native.so` dlopens, is left out: Negotiate
  authentication only.
- **ICU kept:** invariant mode would drop 36 MB, and change how text
  compares and cases, in indexer definitions among others.
- **One archive per platform, checked with `sha256sum -c`:** `ADD
  --checksum` takes one value, and one Bake target builds both
  platforms, so the checksum is picked by a `case` on `TARGETARCH`.
- **`/usr/lib/prowlarr/bin/` and `package_info` beside it:** Prowlarr
  reads `<program folder>/../package_info` only when the folder is named
  `bin`. An update mechanism of `Docker` is `>= External`: the updater
  (which writes into the install folder) is locked off, and the UI shows
  the message to pull a new tag.
- **Pruned from the archive:** `Prowlarr.Update/` (81 MB, the updater),
  `ServiceInstall`, `ServiceUninstall`, `createdump` and
  `libcoreclrtraceptprovider.so` (tools of .NET diagnostics; the provider
  needs `liblttng-ust`), the top-level `*.pdb` and `*.xml` (debug
  symbols, API docs). `UI/`'s XML stays.
- **Analytics off** (`Prowlarr__Log__AnalyticsEnabled=false`): upstream
  sends anonymous usage data by default (`LogOptions.AnalyticsEnabled`).
  An `ENV`: it survives a replaced `CMD`, and the runtime can reset it.
- **`DOTNET_EnableDiagnostics=0`:** the debugger, profiler and EventPipe
  interface serves the pruned tools; off, the runtime opens no
  diagnostic socket.
- **`/config`, a volume, owned by 65532:** `-data=/config`; a named
  volume mounted there starts with that owner. It holds the databases,
  `config.xml`, the logs, the indexer definitions and the ASP.NET key
  ring (`asp/`).
- **A tmpfs on `/tmp` with `--read-only`:** ASP.NET writes each key of
  the ring through `Path.GetTempFileName()`; without it the key ring
  fails to read and write (`Read-only file system : '/tmp/'`). Found by
  running read-only; nothing else in the logs writes outside `/config`.
- **Versions from the Servarr feed, not `github-release-attachments`:**
  Prowlarr publishes no checksum file, so that datasource would hash the
  release's assets, smallest first, until it finds the pinned one (up to
  twelve archives of about 95 MB), and the current version's too, on
  every run. The feed lists each release's archive sha256 (equal to the
  hash of the downloaded archive, both platforms), its date and its
  GitHub URL, master releases only; GitHub also holds develop's, as
  prereleases. The custom datasource `servarr` turns it into
  `version`, `digest` and `releaseTimestamp`, and a `sourceUrl` from the
  download URL. Its URL is each dependency's `registryUrl`, one per
  platform: both dependencies have the same name, so one branch and one
  PR.
- **Both platforms' versions in Bake, checked equal:** each platform is
  its own `# renovate:` entry (the comment's one version and one
  checksum); the build fails on a mismatch.
- **Automerge for minor and patch:** the server test covers start, the
  database migrations, SQLite and the API. Indexer searches are left out:
  they need the network and an indexer's definition. A manual run adds an
  indexer (`POST /api/v1/indexer/test`, Nyaa.si and The Pirate Bay: HTTPS
  with distroless' CA bundle, ICU) before a release line is trusted.
- **The final check is help mode (`-?`)** in exec form: Prowlarr has no
  one-shot mode, and help mode starts no server and opens no database
  (it logs the version and prints the usage). It still loads the runtime,
  which aborts without ICU and the C++ libraries. SQLite is the build
  stage's test.
- **GPL-3.0-only:** `LICENSE` is the GPL v3 text, the source files carry
  no "or later" notice, the API's metadata says `GPL-3.0`.
- **No `HEALTHCHECK`:** Kubernetes ignores it; probes are the
  deployments' (`GET /ping`, anonymous).
