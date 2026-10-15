# datalists

Lists of IP ranges and GeoIP databases, data only on `scratch`, for
images to copy (`containers/haproxy`). Runtime contract, the lists
included: the Containerfile's header. Upstream sources and the reason
for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **One layer per source**, the one changing least first.
- **`--chmod=u=rwX,go=rX` on each `ADD` and `COPY`:** `ADD` gives a
  URL's file 0600, `ADD --unpack` the archive's modes.
- **Done when** the build passes (its `check` stage) and `docker
  export` shows every list root's, files 0644, folders 0755.

## Updates

GeoLite2: P3TERX publishes a release every 3 days and deletes it, tag
included, once two newer exist; Renovate automerges each one, with no
wait (`renovate.json5`), and each file's checksum is the sha256 Renovate
computes. A pinned release that is gone fails the build (`ADD` returns
404), and Renovate can no longer update it (it reads the pinned release
to map each file's digest): set the three entries of `geolite2` in
`docker-bake.hcl` to the newest release, with each file's sha256 from
`gh api repos/P3TERX/GeoLite.mmdb/releases/latest --jq '.assets[] | .name + " " + .digest'`.
Cloudflare's and ipverse's lists are not pinned: each build fetches the
current ones.
