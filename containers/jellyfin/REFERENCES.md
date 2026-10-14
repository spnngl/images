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
  image, and one pin works for both architectures.
- **`jellyfin-ffmpeg8` unpinned**, like Debian's packages: the weekly
  rebuild picks up its fixes. It bundles the hardware drivers (spec
  header). Left out: Intel OpenCL (`intel-opencl-icd` isn't in trixie;
  upstream's image installs GitHub debs, amd64 only) and Rockchip's
  libmali.
- **No web client** (`--nowebclient`): clients are the apps (Android,
  TV) and Seerr; jellyfin-web needs a newer Node.js than trixie's to
  build.
- **Upstream's Docker image layout:** data in `/config`, cache in
  `/cache`, jemalloc, CJK fonts, NVIDIA `video` capability (NVENC/NVDEC).
- **`TMPDIR=/cache`:** Docker and Kubernetes mount no tmpfs on `/tmp`
  (Podman does), so a read-only root filesystem breaks ASP.NET's key
  ring (`Read-only file system : '/tmp/'`). On disk, not in memory:
  Jellyfin extracts attachments and subtitles there.
- **`libmd0` as a runtime dependency:** Dalec 0.22.1 purges dpkg's
  libraries before purging the cleanup tools with dpkg, so that purge
  fails (`libmd.so.0: cannot open shared object file`) and leaves
  dash, coreutils and grep in the image. Kept, dpkg runs and they go.
  Also crowdsec's.
