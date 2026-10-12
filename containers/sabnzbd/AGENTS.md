# sabnzbd

SABnzbd (Usenet downloader, Python) built with Dalec from `spec.yml`:
one Debian trixie package (the app, its Python modules,
par2cmdline-turbo), installed by the `trixie/container` target into an
image built from its dependency closure. The model of every Dalec image.
Runtime contract: the spec's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Gotchas

- Reaching the web UI by a host name other than an IP or `localhost`
  needs it in SABnzbd's `host_whitelist` (Config → Special).
- `Exception in isFAT(...): ... 'df'` at start is harmless.

## Updates

Never automerged. Before merging the PR of a new SABnzbd or uv: run
`containers/sabnzbd/sabnzbd-lock.sh` and commit
`containers/sabnzbd/requirements.lock` if it changed. For a new
SABnzbd, also compare `downloads-dir.patch` with upstream's
`sabnzbd/constants.py`. A checksum-only update means upstream moved the
tag.
