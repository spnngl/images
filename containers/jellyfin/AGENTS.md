# jellyfin

Jellyfin media server (C#/.NET), server only, built with Dalec from
`spec.yml` like `containers/sabnzbd`: one Debian trixie package that
repackages upstream's `jellyfin-server` deb, installed with
`jellyfin-ffmpeg8`. Runtime contract (volumes, ports, probes, hardware
transcoding): the spec's header. Upstream sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- The `jellyfin-server` build dependency stays pinned to
  `${BASE_VERSION}+deb13`, so a version without a package fails the
  build; `jellyfin-ffmpeg8` stays unpinned.
- `TMPDIR` stays `/cache`.
- The spec's server test is `--mode MigrateSystem`, which exits 0;
  `--version` exits 1.

## Updates

Renovate follows the `jellyfin-server` package of Jellyfin's trixie
repository (deb datasource), so a PR comes once the package exists.
Never automerged: a release migrates the database and settings for
good: the old version can't read what the new one wrote. Before
merging, read the release notes
(`https://github.com/jellyfin/jellyfin/releases/tag/v<new>`), back up
`/config`, and check the spec's command-line options against upstream's
`Jellyfin.Server/StartupOptions.cs`. A rotated repository key fails the
build on its digest.
