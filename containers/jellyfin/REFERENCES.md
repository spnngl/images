# jellyfin: references

## Sources

- Upstream: `github.com/jellyfin/jellyfin` at tag `v<BASE_VERSION>`
  (`Jellyfin.Server/StartupOptions.cs`); <https://jellyfin.org/docs/>
- Packages: <https://repo.jellyfin.org> (trixie repository, key
  `jellyfin_team.gpg.key`)
- ffmpeg fork: `github.com/jellyfin/jellyfin-ffmpeg`
- Dalec: `containers/sabnzbd/REFERENCES.md`

## Decisions

- **Repackaged, not built from source:** the package copies
  `/usr/lib/jellyfin/bin` from upstream's `jellyfin-server` deb (an
  `extra_repos` with its key pinned by digest). trixie has no .NET SDK
  and Dalec no NuGet generator: a source build would download the SDK
  and every NuGet package unpinned (upstream has no
  `packages.lock.json`). The deb is a build dependency: its maintainer
  scripts (bash, `adduser`) run in the build container, never in the
  image, and one pin works for both architectures. Upstream's binaries
  stay as is (`disable_strip`: their own build can't strip
  `libpdfium.so`).
- **`jellyfin-ffmpeg8` unpinned**, like Debian's packages: the weekly
  rebuild picks up its fixes. It bundles the hardware drivers: Intel
  (amd64: VA-API, QSV, Vulkan), AMD (VA-API, Vulkan), Rockchip (arm64:
  MPP, RGA). Left out: Intel OpenCL (`intel-opencl-icd` isn't in
  trixie; upstream's image installs GitHub debs, amd64 only; HDR tone
  mapping on Intel falls back to VPP) and Rockchip's libmali.
- **No web client** (`--nowebclient`): clients are the apps (Android,
  TV) and Seerr; jellyfin-web needs a newer Node.js than trixie's to
  build.
- **Upstream's Docker layout:** data in `/config`, cache in `/cache`,
  jemalloc through `LD_PRELOAD`, CJK fonts (posters, burnt-in
  subtitles), NVIDIA capabilities including `video` (NVENC/NVDEC).
- **`TMPDIR=/cache`:** the root filesystem can be read-only, and Docker
  and Kubernetes mount no tmpfs on `/tmp` (Podman does). Without it,
  ASP.NET's key ring fails (`Read-only file system : '/tmp/'`). On
  disk, not in memory: Jellyfin extracts attachments and subtitles
  there.
- **Tests:** ffmpeg and ffprobe run, and the server starts with `--mode
  MigrateSystem` (.NET runtime, SQLite, plugins, an empty database's
  migrations, then exit 0).
