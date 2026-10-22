# flux-aio

Flux, every controller of one release in one image: built from source at
the tags flux2's `manifests/bases/` names, stripped, on `scratch`. Made
for flux-aio's Pod (`github.com/stefanprodan/flux-aio`): one container
per controller, `hostNetwork`. Runtime contract (commands, flags, ports,
env, volumes, cluster side): the Containerfile's header, its one copy.
Upstream sources and the reason for each choice:
[REFERENCES.md](REFERENCES.md).

## Rules

- **Lockstep**: a controller version moves with its Flux release, in one
  commit; the build checks the set, the tags and the Go minor release
  (the Containerfile, before `go build`).
- **Ports**: a listen flag, its port in the header's table and in
  `EXPOSE` change together. Ports only the other controllers call bind
  `127.0.0.1`.
- **No `ENTRYPOINT`, no `CMD`**: each container names its binary.
- **Nothing to exec**: no `git`, no `gpg`; what needs them is off in the
  contract.
- **Vulnerabilities**: no backport and no ignore entry (those files are
  for false positives, `.github/AGENTS.md`); the fix comes with the Flux
  release that ships it, and the code scanning alerts are the list
  meanwhile.
- The build stage runs as UID 65532, with minio's Go cache ids.

## Tests

The build stage's checks (the Containerfile, at its build `RUN`) and one
binary run from `scratch`. The controllers' behaviour is upstream's CI;
a run in a cluster checked them together (`REFERENCES.md`, Checked).

## Updates

One Renovate PR for flux2 and the seven controllers, never automerged.
Controllers are tagged before flux2, so the PR is red until flux2's
tag joins it. Before merging, read the release
(`https://github.com/fluxcd/flux2/releases/tag/v<new>`), then for each
controller that moved, at its new tag:

- `main.go` (source-watcher: `cmd/main.go`): a new listen flag gets a
  contract port in the header and `EXPOSE`;
- `Dockerfile`: a changed build or a new runtime package (an exec
  breaks `scratch`); a new `GO_VERSION` fails the build: move the
  `golang` pin of `docker-bake.hcl` (tag, digest, `extractVersion`) to
  that minor release, in this PR;
- CRDs: apply the release's `install.yaml` before the new image.

The `golang` pin's patch releases, never automerged: the build runs no
controller, so merge after a run in a cluster (`REFERENCES.md`,
Checked). Its digest moves with Saturday's base digests.

A base added to or removed from `manifests/bases/` fails the build: add
or remove the controller everywhere it is named (its `ADD`, its
`version` entry and `main` package in the build `RUN`, its Bake entry
and arguments, the `renovate.json5` group, its ports). A checksum-only
update means upstream moved a tag. `containers/flux-toolbox` pins flux2
too, in its own automerged PR: its version may lead this image's.
