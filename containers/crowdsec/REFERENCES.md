# crowdsec: references

## Sources

- Upstream: `github.com/crowdsecurity/crowdsec` at tag `v<BASE_VERSION>`:
  `Makefile` and `build/mk/` (build flags), `build/docker/` (Dockerfile,
  `config.yaml`, `docker_start.sh`), `wizard.sh` (`--docker-mode`: the
  files of `/etc/crowdsec`), `pkg/csplugin/utils.go` (plugin checks),
  `cmd/crowdsec-cli/core/require/branch.go` (hub branch),
  `pkg/hubops/download.go` (hub downloads); docs
  <https://docs.crowdsec.net>
- Hub: `github.com/crowdsecurity/hub` at the spec's commit (`.index.json`)
- Dalec: `containers/sabnzbd/REFERENCES.md`; `github.com/project-dalec/dalec`
  at the frontend's tag: `packaging/linux/deb/debroot.go` (install,
  postinst, permissions), `targets/linux/deb/distro/container.go` (the
  image)

## Decisions

- **Dalec, with Debian's libre2:** upstream's Makefile links the C++ RE2
  when `pkg-config` finds it (`re2_cgo` tag, `libre2: C++` in
  `crowdsec -version`), much faster than its WebAssembly fallback; the
  image gets `libre2-11` from the package's shlibs. SQLite is
  mattn/go-sqlite3 (cgo), upstream's default.
- **Upstream's Makefile, not a copy of its flags:** `make build` with
  `BUILD_VERSION`, `BUILD_TAG` (the short commit, the source having no
  `.git`), `BUILD_TIMESTAMP` from `SOURCE_DATE_EPOCH`, and `DOCKER_BUILD`
  (cscli's restart hint, the `-docker` User-Agent, as upstream's image).
  Go from trixie-backports, build only, followed by Renovate through
  Repology (`containers/nftables-exporter/REFERENCES.md`).
- **No upstream unit tests:** `make test` needs gotestsum and localstack
  (S3, Kinesis, ...) and many tests reach the network. An automerged Go
  update is checked by the spec's tests only.
- **Root only, no 65532 (unlike the other images):**
  - The agent reads host logs (hostPath `/var/log`, the journal) that
    only root reads; upstream's image runs as root.
  - Every file crowdsec and cscli use must have one owner, the user they
    run as. The plugins: crowdsec refuses the whole plugin folder unless
    each file is owned by its own user, looked up by name
    (`pkg/csplugin/utils.go`), and one file can't have two owners. The
    volumes: a file cscli writes (credentials, hub items) is its user's.
  - A second user would cost a second copy of the plugins (about
    120 MB), a `config.yaml.local` to point at it, and a passwd entry
    Dalec can't create: `artifacts.users` runs `useradd <name>` (UID
    from 1000), so the build would ship its own `/etc/passwd`. Root
    also lets crowdsec run the plugins (which reach the network) as
    nobody: a non-root crowdsec runs them as itself.
  - Debian's base-passwd has root, nobody and nogroup: no passwd file
    of ours.
- **`/etc/crowdsec` and `/var/lib/crowdsec/data` root's, mode 0700:**
  no one else reads the credentials: upstream's 0600 on `config.yaml`
  and the credentials files, for a whole folder, since Dalec's
  `permissions` only applies to an artifact's top. Root's own, so no
  `CAP_DAC_OVERRIDE`.
- **Upstream's Docker config:** `config.yaml` is
  `build/docker/config.yaml` with `plugin_dir` in `/usr/lib/crowdsec`
  and `nogroup` (Debian has no `nobody` group). `profiles.yaml`,
  `simulation.yaml`, `console.yaml`, `patterns/`, the plugins' configs,
  upstream's `local_api_credentials.yaml` and dummy `acquis.yaml` (the
  agent won't start without a data source) come as `wizard.sh
  --docker-mode` and the Dockerfile install them. Changes go in a
  `config.yaml.local`, or `acquis.d/`.
- **No `docker_start.sh`:** it needs bash. Each of its steps is an
  explicit `cscli` run (spec's header); the Local API credentials file
  stays as upstream ships it until `cscli machines add --auto` writes
  the login.
- **Hub items preinstalled, from a pinned hub commit:** upstream's
  Dockerfile installs `crowdsecurity/linux` and
  `crowdsecurity/whitelists`, `docker_start.sh` always
  `crowdsecurity/docker-logs` and `crowdsecurity/cri-logs`. The hub is
  pinned by commit of `master`, the branch cscli picks for the latest
  release, and Renovate follows its digest, weekly and automerged: it
  changes several times a day, and the spec's tests install from it.
  Every item is decoded from
  the index into `/etc/crowdsec/hub` (cscli then installs without
  download, and later installs of other items need no network for
  their YAML); cscli links the installed ones by absolute path, so the
  build writes the real `/etc/crowdsec`. `--branch master` only avoids
  cscli's lookup of the latest version (network).
- **`DH_OPTIONS: -X.yaml`:** dh_link rewrites absolute links within one
  top-level folder as relative (Debian policy), and cscli only removes
  an item whose link is exactly the hub file's absolute path. Checked
  in debhelper (trixie): with `DH_OPTIONS` (not `DH_ALWAYS_EXCLUDE`)
  `dh_builddeb` drops nothing, and the other commands would only skip
  chmods these 0644 files don't need. The spec's tests remove an item.
- **No hub data files (GeoLite2, allowlists):** they come unversioned
  from `hub-data.crowdsec.net`, which the build can't reach or pin, and
  crowdsec only logs their absence. `cscli hub upgrade` downloads them
  into the data volume.
- **ca-certificates and tzdata:** HTTPS to the Central API, the hub and
  the notification services; upstream's image has tzdata for log
  timestamps.
- **Entrypoint `crowdsec`:** cscli runs with `--entrypoint
  /usr/bin/cscli`.
