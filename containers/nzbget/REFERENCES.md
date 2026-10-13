# nzbget: references

## Sources

- Upstream: `github.com/nzbgetcom/nzbget` at tag `v<BASE_VERSION>`
  (`nzbget.conf`, `cmake/posix.cmake`, `cmake/par2-turbo.cmake`,
  `cmake/rapidyenc.cmake`, `daemon/main/Options.cpp`); <https://nzbget.com>
- par2cmdline-turbo and rapidyenc: NZBGet's forks,
  `github.com/nzbgetcom/par2cmdline-turbo`, `github.com/nzbgetcom/rapidyenc`
- Upstream's container: `docker/` of NZBGet's repository
- Dalec: `github.com/project-dalec/dalec`, docs
  <https://project-dalec.github.io/dalec/>

## Decisions

- **Dalec, as `containers/sabnzbd/`:** NZBGet links Debian's libxml2,
  OpenSSL and zlib, and runs unrar, 7-Zip and Python.
- **par2cmdline-turbo and rapidyenc pinned in the spec**
  (`pinned-libs.patch`): NZBGet's build clones them at the tag its cmake
  file names, and the Dalec build has no network. Pinned by commit like
  NZBGet; the spec checks they are the tags NZBGet names. One Renovate
  PR for the three (`renovate.json5`): Renovate can't read NZBGet's cmake
  files, so it can't pick the libraries' tags from them.
- **First start writes `/config/nzbget.conf`** (`default-config.patch`):
  NZBGet exits when the `-c` file doesn't exist, and upstream's container
  copies it with a shell script, which this image can't run. The copy is
  the image's `/usr/lib/nzbget/nzbget.conf`, also `ConfigTemplate`.
- **Defaults patched into `nzbget.conf`** (`defaults.patch`): NZBGet
  takes no env variable for them, and `-o` on the command line would pin
  them, hiding the web UI's changes.
  - `MainDir=/downloads`, with upstream's `dst`, `inter`, `nzb`, `tmp`
    under it; `QueueDir`, `ScriptDir` and `LogFile` in `/config`, so
    `/config` holds the state and `/downloads` the files. Upstream's
    container keeps everything in `/downloads`, renamed.
  - `WebDir`: the web UI in `/usr/lib/nzbget/webui`, where upstream's
    `cmake/install.cmake` writes it into its copy of the configuration.
  - `CertStore` Debian's CA bundle, `CertCheck=yes`: news servers' TLS
    certificates are checked.
  - `UpdateCheck=none`: Renovate updates the image.
  - `OutputMode=log`: built without curses (`DISABLE_CURSES`), no
    terminal.
  - `UnrarCmd` and `SevenZipCmd` by absolute path. `/usr/lib/7zip/7za`:
    Debian's `/usr/bin/7za` and `/usr/bin/7z` are shell scripts.
  - `ShellOverride=.py=/usr/bin/python3`: extensions are mostly Python,
    and NZBGet finds an interpreter through `/bin/sh` or the script's
    `#!/usr/bin/env` line, which the image lacks.
- **Login left at upstream's default:** an empty `ControlPassword`
  disables authentication, and a password in the image breaks the
  repository's rule. The user sets one at runtime (spec header).
- **`-s`:** server in the foreground; the lock file and `DaemonUsername`
  are daemon mode's only.
- **Licenses kept in `/usr/share/doc`:** par2cmdline-turbo (GPL-2.0) and
  rapidyenc's crcutil (Apache-2.0) are linked statically; rapidyenc
  itself is public domain.
