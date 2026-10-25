# rclone: references

## Sources

- Upstream: `github.com/rclone/rclone` at tag `v<BASE_VERSION>`:
  `bin/cross-compile.go` and `.github/workflows/build.yml` (release
  build), `Dockerfile` (upstream's image), `fs/config/config.go`
  (config and cache paths), `docs/content/install.md` (Docker usage)
- FUSE: `github.com/libfuse/libfuse` at trixie's `fuse3` version
  (`util/fusermount.c`); `github.com/hanwen/go-fuse` (`mount2`) and
  `bazil.org/fuse` (`mount`) at `go.mod`'s versions (`mount_linux.go`)
- Dalec: `containers/sabnzbd/REFERENCES.md`

## Decisions

- **Dalec, not a static binary on `scratch`:** `rclone mount` runs
  `fusermount3` (go-fuse and bazil/fuse look it up on the `PATH`), a
  setuid C binary from Debian's `fuse3`. The rest of rclone runs no
  program but the commands a user configures (`--password-command`,
  sftp's `ssh`): none ship.
- **Upstream's release build:** `CGO_ENABLED=0 go build -trimpath` with
  `-s -X github.com/rclone/rclone/fs.Version=v<BASE_VERSION>`. Its
  `cmount` tag needs cgo on Linux (`cmd/cmount/mount.go`), so upstream's
  Linux binary has no `cmount` either; `mount` and `mount2` remain.
- **`noselfupdate`:** the image is the update; a self-updated binary
  would be lost with the container.
- **Go from trixie-backports, build only:** as
  `containers/nftables-exporter`; trixie's golang-go is older than
  `go.mod` requires. Modules from Dalec's `gomod` generator, pinned by
  `go.sum`.
- **Tests in the build, on which Renovate automerges rclone and Go:**
  upstream's `go test` of `fs/sync`, `fs/operations` and
  `backend/local`, what deletes or overwrites data, on local folders;
  then `serve s3` and the S3 backend through one round trip, read back
  with curl: both directions of rclone's network code.
- **Mount as root only:** for any other UID, `fusermount3`
  (`util/fusermount.c`) needs its setuid bit, inert under
  no-new-privileges; looks up the caller's passwd entry
  (`get_user_name`), and the image has none; and mounts only over
  whitelisted filesystem types (`check_perm`), which Docker Desktop's
  bind mounts aren't (`mounting over filesystem type 0x6a656a63 is
  forbidden`). Root, with `CAP_SYS_ADMIN` and `/dev/fuse`, skips its
  permission checks and may pass `allow_other` without
  `/etc/fuse.conf`. Docker's default AppArmor profile denies `mount`.
  Kubernetes allows `Bidirectional` propagation only to privileged
  containers.
- **`RCLONE_CONFIG=/config/rclone/rclone.conf`:** upstream image's path
  (`XDG_CONFIG_HOME=/config`), so its docs apply. Set as the file, not
  the folder: with `XDG_CONFIG_HOME` and no mounted `/config`, rclone
  falls back silently to `/.rclone.conf` (`fs/config/config.go`).
- **`XDG_CACHE_HOME=/cache`, not `RCLONE_CACHE_DIR`:** bisync's
  `--workdir` and the cache backend's paths default to the cache folder
  when the program loads, before the environment is read
  (`cmd/bisync/cmd.go`, `DefaultWorkdir`). The default, `~/.cache`, is
  `/.cache` (runc's `HOME=/` without a passwd entry), read-only.
- **`working_dir: /data`:** upstream image's, so its docs' relative
  paths and `/data/mount` apply.
- **No volume declared:** Docker would create it root's, unwritable by
  65532. The header names the folders to mount.
- **The closure:** `ca-certificates` (HTTPS to the providers),
  `media-types` (`/etc/mime.types`, as upstream's Alpine `mailcap`:
  Content-Type of uploads and of serve), `fuse3`. `fuse3` depends on
  `adduser`, `mount` and `sed`, which bring `passwd`, PAM and their
  setuid binaries (`chfn`, `chsh`, `gpasswd`, `passwd`, `mount`,
  `umount`): inert under no-new-privileges, which the header requires.
  Building `fusermount3` from libfuse instead would save about 10 MB
  and those binaries, but leave a setuid binary without Debian's
  security updates. No `tzdata`: Go ignores `TZ` without it, times are
  UTC.
- **No port in the labels or header but upstream's defaults:** each
  serve protocol has its own, and most listen on localhost until
  `--addr` says otherwise.
