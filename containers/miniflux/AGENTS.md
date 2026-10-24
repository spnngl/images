# miniflux

Miniflux (feed reader, web UI and API, Go): upstream's release built
from source as tagged, no patch, one static binary on `scratch`, its
state in an external PostgreSQL. Runtime contract: the Containerfile's
header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- The server test's scaffolding stays in the build stage: PostgreSQL,
  the build user's passwd entry, the feed server,
  `FETCHER_ALLOW_PRIVATE_NETWORKS=1`. The image gets the binary, the CA
  bundle, the time zones and the license.
- The build stage runs as UID 65532, with the Go cache ids
  `containers/minio` uses.
- Settings that must survive a replaced `CMD` go in the environment, as
  `LISTEN_ADDR` does.
- Probes: `/liveness` (`/healthz`) and `/readiness` (`/readyz`) on 8080,
  at the root whatever `BASE_URL`; `/healthcheck` under `BASE_URL`'s
  path, the one the `HEALTHCHECK` (`miniflux -healthcheck auto`) queries.

## Smoke tests

The build stage's server test, step by step in its Containerfile
comment: version and commit, schema migration and admin creation on a
throwaway PostgreSQL, the image's health check, the login page, API
authentication, a category written and read back, a local RSS feed
fetched and its entry read back. The final stage runs `miniflux -version`.

## Updates

Renovate follows the unprefixed `<x.y.z>` tags; releases merge by hand
(REFERENCES.md). Before merging, read the release notes and back up the
database. Then diff upstream's new tag against the old one in the files
REFERENCES.md's *Sources* lists: done when every flag, variable and
endpoint the Containerfile names still exists and behaves as its comment
says, and the build matches the Makefile's `linux-*` targets.

A checksum-only update means upstream moved the tag.
