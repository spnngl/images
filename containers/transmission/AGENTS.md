# transmission

Transmission (BitTorrent daemon, C++), its web UI and
`transmission-remote`, built with Dalec from `spec.yml`: one Debian
trixie package, installed by the `trixie/container` target into an image
built from its dependency closure, like `containers/sabnzbd/`. Runtime
contract: the spec's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Settings

The image sets none: upstream's defaults, then `/config/settings.json`
(a partial file is valid), then the args (`-t -u <user> -v <password>`).
Configure by mounting a complete `settings.json`, e.g. a ConfigMap file.
Keys: snake_case or kebab-case, upstream reads both and writes kebab-case.

Set at least:

- `download_dir`: upstream's default is `//Downloads` (no `HOME`).
- `rpc_whitelist_enabled: false`: upstream allows `127.0.0.1` and `::1`
  only (a login lifts the host whitelist, not this one).
- a login: `-t -u -v`, or `rpc_authentication_required`, `rpc_username`,
  `rpc_password`. Without one, anyone reaching 9091 controls the daemon,
  `script_torrent_done_filename` included.

The daemon rewrites `settings.json` (every setting, web UI changes
included) at start, at exit and on `SIGHUP`; the state is in other files
(`stats.json`, `resume/`, `torrents/`, `queue.json`). Edit a writable
`settings.json` with the daemon stopped. On a read-only file mount the
save logs `Couldn't save '/config/settings.json': Device or resource
busy` and the daemon runs on; web UI changes last until the restart.
Each failed save leaves a `settings.json.tmp.<random>` in `/config`.

## Gotchas

- Scripts (`script_torrent_done_filename`...) run directly: the image has
  no shell.
- `watch_dir` on NFS or SMB: inotify misses remote writes, set
  `watch_dir_force_generic: true` (it polls).
- First start logs `Couldn't read '/config/settings.json'` and
  `queue.json`: harmless.

## Updates

Automerged for minor and patch releases once the build and its tests
pass (`depType=automerge`); majors by hand. A checksum-only update means
upstream moved the tag.
