# nzbget

NZBGet (Usenet downloader, C++) built with Dalec from `spec.yml`: one
Debian trixie package (the binary, its web UI and default
configuration), installed by the `trixie/container` target into an
image built from its dependency closure, like `containers/sabnzbd/`.
Runtime contract: the spec's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- par2cmdline-turbo and rapidyenc are the tags NZBGet's
  `cmake/par2-turbo.cmake` and `cmake/rapidyenc.cmake` name: the spec's
  first build step fails otherwise.
- A path the image's configuration points at (`defaults.patch`) has a
  test step in the spec.

## Gotchas

- The web UI's login is upstream's public default until changed (spec
  header).
- Extensions run with `/usr/bin/python3`: shell ones fail, the image has
  no shell.
- An existing `/config/nzbget.conf` is kept: the image's defaults only
  apply to a new one.

## Updates

Never automerged. NZBGet, par2cmdline-turbo and rapidyenc come in one
PR: it fails while a library's newest tag is one NZBGet doesn't name
yet, and passes once NZBGet's release does. For a new NZBGet, check that
the three patches still apply (the build fails otherwise) and compare
`defaults.patch` with upstream's `nzbget.conf` for new paths. A
checksum-only update means upstream moved the tag.
