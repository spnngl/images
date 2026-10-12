# sabnzbd

SABnzbd (Usenet downloader, Python) built with Dalec from `spec.yml`:
one Debian trixie package (the app, its Python modules,
par2cmdline-turbo), installed by the `trixie/container` target into an
image built from its dependency closure. The model of every Dalec image.
Runtime contract: the spec's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- Python modules come from `requirements.lock`, hash-pinned, installed
  by uv. Regenerate it with `containers/sabnzbd/sabnzbd-lock.sh`.
- The spec's tests run every tool from the path SABnzbd finds it at
  (`7za` through `/usr/local/bin/7za`).
- Reaching the web UI by a host name other than an IP or `localhost`
  needs it in SABnzbd's `host_whitelist` (Config → Special).
- `Exception in isFAT(...): ... 'df'` at start is harmless.

## Updates

Never automerged. In the PR of a new SABnzbd or uv: run
`sabnzbd-lock.sh` and push the lock. For a new SABnzbd, also check
`downloads-dir.patch` against upstream's `sabnzbd/constants.py`.
