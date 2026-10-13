# busybox

BusyBox built from source: one static musl binary on `scratch`, with a
link per applet as upstream's `make install` lays them out. A utility
and debugging image, and a binary to `COPY --from`. Runtime contract:
the Containerfile's header. Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Configuration is upstream's `defconfig` plus `static_defconfig`**,
  which holds only the image's changes, each with its reason. Disable an
  applet there (`# CONFIG_<X> is not set`); the source stays unpatched.
- **`CC=musl-gcc` on every `make`:** one without it rebuilds the binary
  with gcc, against glibc.
- **The build runs in `/build`, a copy of the source:** busybox's
  configuration writes into its source tree, which `ADD` makes root's.
- **`/etc/passwd` and `/etc/group` name the image's `USER`** (nonroot,
  65532, `HOME` `/tmp`), passwords locked (`*`).
- **Done when** the build passes: its stages check every applet link,
  run applets through the image's shell, and fail unless the binary is
  static and `whoami` prints `nonroot`.

## Updates

Never automerged: the smoke test covers a few applets, not upstream's
changes. Before merging, read the release notes
(<https://busybox.net/news.html>). A build failing on an applet the new
`defconfig` enables: disable it in `static_defconfig`, with its reason.
A checksum-only update means upstream moved the tag.
