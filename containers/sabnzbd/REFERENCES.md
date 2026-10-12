# sabnzbd: references

## Sources

- Upstream: `github.com/sabnzbd/sabnzbd` at tag `<BASE_VERSION>`
  (`requirements.txt`, `sabnzbd/constants.py`); <https://sabnzbd.org>
- par2cmdline-turbo: `github.com/animetosho/par2cmdline-turbo`
- Dalec: `github.com/project-dalec/dalec`, docs
  <https://project-dalec.github.io/dalec/>

## Decisions

- **Dalec, not a Containerfile on distroless:** the image keeps a dpkg
  database, so scanners see every Debian package and its version, at
  about distroless' size, without shell or apt. Distroless can't be the
  base: Dalec installs with dpkg, and distroless has no
  `/var/lib/dpkg/status` (base-files' postinst fails).
- **Sources pinned by commit:** Dalec checks that the sabnzbd and
  par2cmdline-turbo tags resolve to the spec's commits.
- **Python modules from PyPI, not Debian:** Debian's are older than
  SABnzbd requires. `requirements.lock` is upstream's
  `requirements.txt` without notify2 (desktop notifications), every
  module pinned with its hashes; uv installs it (`--require-hashes`, the
  build's only network access) into `/usr/lib/sabnzbd/site-packages`,
  found through a `.pth` file. Bytecode is compiled at build time (the
  user can't write `/usr/lib`).
- **par2cmdline-turbo from source:** SABnzbd's recommended par2; trixie
  only has par2cmdline 0.8.1. unrar from trixie's `non-free`, for the
  image only.
- **Licenses kept in `/usr/share/doc`:** par2cmdline-turbo's `COPYING`
  (GPL-2.0) is a `licenses` artifact. Declaring one makes
  `trixie/container` keep the whole tree, Debian's `copyright` files
  included (about 4 MB); without it Dalec deletes all of it.
- **`/usr/local/bin/7za`, a symlink to `/usr/lib/7zip/7za`:** Debian's
  `/usr/bin/7za` is a shell script.
- **Downloads in `/downloads/{incomplete,complete}`**, patched into
  SABnzbd's defaults (`downloads-dir.patch`): otherwise they land in
  `/config/Downloads/`, and no option or variable moves them.
