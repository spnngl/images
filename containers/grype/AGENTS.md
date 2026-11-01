# grype

anchore/grype (vulnerability scanner for container images and
filesystems, Go) built from source as tagged, no patch, one static
binary on `scratch`, like `containers/mc`: same build, user and layout.
A one-shot CLI: it scans and exits, so run it as a Job or CronJob, or
as an init container (`grype db update`). Sources: registries and
archives; no Docker socket. Runtime contract: the Containerfile's
header. Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Updates

Renovate follows the repository's tags, automerged once CI passes
(patch and minor; majors by hand): the build downloads the real
vulnerability database and scans a package it knows is vulnerable
(Log4Shell), which covers what a release or a Go bump can break. A new
database schema (`v6` to `v7`) downloads into a new
`/cache/grype/db/<schema>/`, the old one left to delete. What changed:
`https://github.com/anchore/grype/compare/<old>...<new>`.

The build needs the network (`grype.anchore.io`): an outage there fails
the build, not the image.
