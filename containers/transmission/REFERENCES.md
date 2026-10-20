# transmission: references

## Sources

- Upstream: `github.com/transmission/transmission` at tag `<BASE_VERSION>`
  (no `v`): `CMakeLists.txt` (options, `USE_SYSTEM_*`, `TR_VCS_REVISION`),
  `cmake/Find*.cmake`, `libtransmission/session.cc`
  (`tr_sessionLoadSettings`, `tr_sessionSaveSettings`),
  `libtransmission/variant.cc` (`to_file`), `libtransmission/platform.cc`
  (`TRANSMISSION_HOME`, `TRANSMISSION_WEB_HOME`),
  `libtransmission/rpc-server.h`, `docs/Editing-Configuration-Files.md`;
  <https://transmissionbt.com>
- Debian's packaging, for the libraries: trixie-backports'
  `transmission` `4.1.3+dfsg-1~bpo13+1`, which builds against trixie's
  libraries (`use-system-libs.patch` for the header-only ones)
- BuildKit `source/git/source.go` (v0.31.2, the one Dalec 0.22.1 pins):
  Git sources fetch submodules
- Dalec: `github.com/project-dalec/dalec`, docs
  <https://project-dalec.github.io/dalec/>

## Decisions

- **Dalec, as `containers/sabnzbd/`:** the daemon links libcurl (nghttp2,
  ssh2, rtmp, ldap, krb5, brotli, zstd, idn2...), OpenSSL and libevent.
  That closure is too large to copy by hand onto `cc-debian13` as
  `containers/haproxy` does; Dalec computes it from the package.
- **Debian's libraries wherever upstream can use one:** libcurl, OpenSSL
  (`WITH_CRYPTO=openssl`), zlib, and `USE_SYSTEM_{EVENT2,DEFLATE,PSL,
  MINIUPNPC,NATPMP,B64}=ON`, forced, so a missing `-dev` package fails the
  build instead of bundling silently. Security updates of these come
  with Debian's.
  - **Bundled:** DHT (`dht`) and µTP (`libutp`): no trixie package
    (checked on amd64 and arm64), so their submodules build in. fmt,
    rapidjson, fast_float, utfcpp, small and wide-integer are
    header-only and upstream has no system switch for them (Debian
    patches one in; not worth carrying).
- **Git source with submodules:** upstream's third-party code is 16
  submodules; BuildKit's git source runs
  `git submodule update --init --recursive --depth=1`, and the
  superproject commit pins them. `commit` is the tag and `checksum` its
  commit, as in the other specs.
- **Web UI prebuilt, no Node.js:** `web/public_html` is in the source
  (`REBUILD_WEB=OFF`). Installed in `/usr/lib/transmission/public_html`
  (Dalec prunes `/usr/share`), found through `TRANSMISSION_WEB_HOME`
  (`platform.cc`).
- **`TRANSMISSION_HOME=/config`:** the settings, torrents and resume
  data in one volume, so the args never need `-g`. No `HOME`: only
  upstream's default download folder reads it (`//Downloads` without),
  which `settings.json` replaces.
- **`REVISION` file:** upstream shows the git revision in `-V`; the
  source has no `.git`, and `CMakeLists.txt` reads `REVISION` then.
- **Daemon and `transmission-remote` only:** the utils build `create`,
  `edit`, `remote` and `show`; only `remote` is useful in a shell-less
  image (`kubectl exec <pod> -- /usr/bin/transmission-remote -n
  user:pw -l`). No GUI, no CLI client, no systemd notification, no
  translations, no documentation.
- **`--foreground`:** the daemon stays in the foreground and logs to
  stderr. No `cmd`: the args are the user's (`-t -u -v`).
- **No settings in the image, no patch:** a complete `settings.json`
  mounted by the user (a ConfigMap file) replaces layered defaults and a
  patch of `daemon/daemon.cc` to re-check on each release. Upstream has
  that one file and no env variable per setting. It is safe to mount
  read-only: the daemon's save (`tr_sessionSaveSettings`) holds settings
  only, the statistics are `stats.json`, and `to_file` logs and returns
  on failure (tested: `Device or resource busy`, a `settings.json.tmp.*`
  left per save). What the user must set: `AGENTS.md`, Settings.
- **No login by default:** a password in the image breaks the
  repository's rule. The user sets one at runtime (spec header).
- **No `EXPOSE`, no metrics:** Dalec has no field for exposed ports
  (0.22.1 and `main`), so the spec's comment lists them, as
  `containers/jellyfin`. Upstream has no metrics endpoint (4.1.3): an
  exporter in the same pod reads the RPC on `127.0.0.1:9091`.
- **Test stdout with escaped quotes:** the spec's `contains` strings
  are split like shell words, so the JSON's `"` are written `\"`. `-d`
  prints the settings (snake_case) and exits without writing.
- **No test with a mounted `settings.json`:** it passed locally (arm64,
  docker and docker-container builders) and failed on CI's builders
  (`Couldn't read '/config/settings.json': Permission denied`, with the
  file 0644 and `/config` 0755, readable by the test runner's file
  checks). Cause not found; the test checks the image sets no setting.
- **Renovate, `depType=automerge`:** minor and patch releases merge once
  the build and its tests pass. Tags are `4.1.3`, no `v`; betas
  (`4.1.0-beta.5`) are prereleases Renovate skips.
- **License:** `GPL-2.0-only OR GPL-3.0-only` (upstream's `COPYING`, with
  the OpenSSL exception); the bundled code's texts are in `licenses/`,
  shipped with the binary.
