# crowdsec

CrowdSec's security engine (Go): `crowdsec` (agent and Local API),
`cscli` and the notification plugins, built with Dalec from `spec.yml`
like `containers/sabnzbd`: one Debian trixie package, linked to Debian's
libre2, with upstream's Docker config and the hub items its image
installs. Runtime contract (root, volumes, ports, the `cscli` runs that
replace upstream's `docker_start.sh`): the spec's header. Upstream
sources and the reason for each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **Build natively:** a cross build (QEMU) fails in Dalec's `gomod`
  generator with `exec: "sh": executable file not found in $PATH`.
- **Root owns every file crowdsec and cscli use**, its only user: crowdsec
  loads no plugin unless each file of the plugin folder is its user's,
  neither group- nor world-writable (`pkg/csplugin/utils.go`).
- **`plugin_config` names users of Debian's base-passwd**
  (nobody:nogroup): the image adds none.
- **Hub items install offline**, from the hub index's embedded content;
  their data files come at runtime (`cscli hub upgrade`).
- **Done when** the build passes: the spec's tests run in the final
  image.

## Updates

- **A CrowdSec release** is never automerged. Before merging, port
  upstream's `build/docker/config.yaml`, `build/docker/Dockerfile` and
  `docker_start.sh` changes
  (`https://github.com/crowdsecurity/crowdsec/compare/v<old>...v<new>`)
  to `config.yaml` and the spec. A checksum-only update means upstream
  moved the tag.
- **CI fails on `go.mod requires go >= ...`:** bump
  `golang-<version>-go` in the spec.
- **A Dalec update:** try dropping `libmd0` from the runtime
  dependencies (the spec's TODO).
- **The hub** is a `master` digest, automerged in the Saturday group
  (`renovate.json5`).
