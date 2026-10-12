# Architecture

This repository builds [bootc](https://bootc.dev/bootc/) images: bootable
operating systems shipped as OCI container images. A bootc host boots from
an image and updates by pulling a newer one (`bootc upgrade`), the same way
a container is updated. Four folders are not bootc images but
application images, containers the hosts run: `images/cs-firewall-bouncer`,
`images/sabnzbd`, `images/nftables-exporter` and `images/jellyfin`, the
last three built with Dalec, not a Containerfile (see their sections).

For a bootc image there are two stages:

1. **Container image**: `podman build` on `images/<name>/Containerfile`.
   This is what hosts boot and update from.
2. **Disk image**: [image-builder](https://github.com/osbuild/image-builder)
   turns the container image into a qcow2 used for the first install. Later
   updates come from the container image, not from a new disk image.

## Layout

```
.
├── .github/
│   └── workflows/
│       ├── build-bootc.yml     # CI: lint, build, push the bootc images
│       ├── build-apps.yml      # CI: lint, build, push the changed application images
│       │                       # the next four call spnngl/.github's:
│       ├── renovate.yml        # CI: validate renovate.json5
│       ├── conventional-commits.yml  # CI: commit messages of a PR
│       ├── betterleaks.yml     # CI: secrets in the git history
│       ├── betterleaks-github.yml    # daily: secrets in PRs, issues
│       └── image-scan.yml      # daily: vulnerabilities of the pushed images
├── .hadolint.yaml              # hadolint config for every Containerfile
├── images/                     # shared build context for every image
│   ├── .containerignore        # keeps every Containerfile out of `COPY . /`
│   ├── k3s/                    # shared by every kubeenv stage (not an image)
│   │   ├── install.sh          # k3s and CRI-O install
│   │   └── sysroot/...         # CRI-O configuration, kube.slice, swap
│   └── <name>/                 # one folder per image (bootc, or application
│       │                       # image: cs-firewall-bouncer)
│       ├── Containerfile       # or spec.yml, for a Dalec image: sabnzbd,
│       │                       # nftables-exporter, jellyfin
│       └── sysroot/...         # files copied as is into the image root
│                               # (bootc: common/, then <BASE_VERSION>/)
├── scripts/
│   ├── build.sh [name]         # container image, then output/<name>/<name>.qcow2
│   ├── sabnzbd-lock.sh         # regenerate images/sabnzbd/requirements.lock
│   └── run.sh [name]           # boot the qcow2 in QEMU (macOS Apple Silicon)
├── config.example.toml         # template for config.toml (git-ignored)
├── K3S.md                      # setting up k3s hosts (kubeenv images)
├── renovate.json5              # Saturday updates of every pinned version
└── output/                     # build results (git-ignored)
```

## Images

### `images/fedora`

An image derived from `quay.io/fedora/fedora-bootc:44`, with either
Docker or k3s. Stages:

- `base`: the host system, shared by the two images below. Not an image
  on its own.
- `dockerenv` (`FROM base`, the last stage, so the default target and
  what `build.sh` builds): adds Docker. Tag `<name>:<version>`.
- `kubeenv` (`FROM base`, `podman build --target kubeenv`): adds k3s, no
  Docker. Tag `<name>:<version>-v<Kubernetes minor release>k3s`. Every
  image's `kubeenv` runs the
  same `images/k3s/install.sh`, bind-mounted rather than copied (buildah
  still keys its cache on the script's content). It installs k3s in
  `/usr`, with a unit per role, both disabled: each host picks its role
  by hand. The k3s release (its tag, `v<Kubernetes release>+k3s<build>`)
  is the stage's `ARG INSTALL_K3S_VERSION`, set by CI from the matrix's
  `k3s`, like `BASE_VERSION`. The tag carries the Kubernetes minor
  release only: a patch release or a new k3s build reaches hosts with
  `bootc upgrade` (k3s upgrades in place within a minor release), and
  only a minor release, a new tag, needs a `bootc switch`, which is also
  when to follow Kubernetes' upgrade notes. Renovate bumps the matrix's
  `k3s` and `suffix` in one replacement, and the Containerfiles' default,
  in one PR (see "Updates").
  The container runtime is CRI-O (same minor release, with crun),
  configured by `images/k3s/sysroot/`, copied after the script, which
  also puts k3s and CRI-O in `kube.slice`, out of `system.slice`, and
  sets up swap on zram, which pods use through the kubelet's
  `LimitedSwap` (K3S.md, "Swap"). Cilium
  is the CNI. Setup and firewall: [K3S.md](K3S.md); the reasons are in
  the script, next to each step.

Both images end with `bootc container lint`. The host system:

- Installs `htop`, `vim`, `git` and what the configuration below needs, then
  empties `/var/log`, `/var/cache`, `/var/lib/dnf`, `/tmp` and `/run/dnf*`.
- `usr/lib/bootc/kargs.d/10-console.toml`: serial console kernel
  arguments, x86_64 only.
- `usr/lib/bootc/install/50-rootfs.toml`: default root filesystem `btrfs`.
  The Fedora base image sets none, so without this file both
  `bootc install to-disk` and image-builder would need a filesystem flag.
- System configuration that bootc disk images don't accept from the
  blueprint: hostname, timezone, locale, NTP servers (chrony), DNS
  (systemd-resolved drop-in; `etc/systemd/network/wired.network` ignores
  the DHCP servers' DNS), sshd on port 42022 (SELinux port label and firewalld port),
  enabled and masked services. `config.toml` only holds the user.
- Registry authentication: one pull secret, `/etc/ostree/auth.json`
  (0640 root:wheel), machine-local and never in the container image. It
  can be added to the disk image by `config.toml`.
  bootc reads it directly. `usr/lib/tmpfiles.d/container-auth.conf` links
  root's `~/.docker/config.json` to it, which podman and docker both read.
- Image signature verification: `ghcr.io/spnngl/images/*` must be
  signed by CI's key. See "Signing" below.
- Firewall: `public` zone opens 80/443/42022, then drops `ssh` (22) and
  `cockpit` from it (sshd only listens on 42022, and cockpit isn't
  installed). See "Firewalld" below for the `firewall-offline-cmd` option
  this needs.

### `images/almalinux`

An image derived from `quay.io/almalinuxorg/almalinux-bootc:10`,
close to `images/fedora` (Docker, firewalld, the same TZ and chrony setup),
plus country geo-blocking and threat-feed blocklists on the public
zone. Same stages, `dockerenv` and `kubeenv`, as `images/fedora`.

Geo-blocking and blocklists:

- Two firewalld policies sit on the `public` zone: `geoblock`
  (priority -10000) drops private/link-local sources (the static,
  committed ipset `geoblock-bogons`) and sources in a blocked
  country (the `countries` list in the Containerfile's `geoblock`
  stage); `blocklist` (priority -9000) then drops sources
  listed by 10 public threat feeds. Both `target=CONTINUE`, so traffic
  that isn't dropped still goes through the existing `public` zone rules
  unchanged.
- IPv4 only, like the rest of both images: IPv6 is disabled by
  `images/fedora/sysroot/common/etc/sysctl.d/990-disable-ipv6.conf`. IPv6
  entries in the threat feeds are skipped.
- The country and blocklist data is baked in at build time, not fetched
  at runtime. A build-only stage, `geoblock`, downloads the ipdeny zones
  of every country (one archive) and the feeds with `ADD`, then
  `images/almalinux/geoblock.nu` turns the blocked countries and the
  feeds into firewalld ipsets. The stage is the `ghcr.io/nushell/nushell`
  image with nushell as its `SHELL`: its `RUN` is nushell code.
  Both ipsets are compacted: overlapping and adjacent networks merge into
  the fewest covering the same addresses (ipdeny's zones aren't
  aggregated, and the feeds overlap). Feed entries inside a blocked
  country are left out: the `blocklist` policy never sees that traffic,
  so they can never match. Nothing from that stage reaches the final
  image except the generated ipsets, each blocked country's compacted
  networks (`/usr/share/geoblock/countries`) and the raw feeds
  (`/usr/share/geoblock/blocklists`), kept so a blocked IP can be traced
  to its country or feed.
- Countries are geolocated by address registration, not by where a
  server is: the US zone also covers the European regions of US clouds
  (AWS, GCP, Azure), Cloudflare and GitHub. Blocking it drops their
  inbound traffic (webhooks, monitoring, proxied requests); outbound
  connections and their replies still work.
- A blocklist fails closed: corrupt country data blocks legitimate
  traffic, possibly the admin's. `geoblock.nu` fails the build on any
  invalid entry, on an empty country file and on a country network that
  overlaps a bogon range (which `0.0.0.0/0` would).
- Refresh means rebuild: there is no timer and no cron job. `ADD` keys its
  cache on the fetched content's digest, so a build only reruns the steps
  that changed.
- `firewall-offline-cmd --check-config` does not validate ipset entries,
  so `geoblock.nu` is the only thing that does. Its tests
  (`images/almalinux/test_geoblock.nu`) run before it processes the real
  data, on every build.
- A reverse proxy such as Caddy must run with `network_mode: host`:
  Docker publishes ports (`-p`) by DNATing before firewalld's policies
  run, so published ports bypass both. Its backends are published on
  loopback only. Consequence: ACME must use the DNS-01 challenge, since
  Let's Encrypt validates HTTP-01 from several regions.
- Kill switch: copy a policy file to `/etc/firewalld/policies/`, add
  `<disable/>`, `firewall-cmd --reload`. Disable `geoblock` and
  `blocklist` together, not just one.
- Two x86_64 builds, like the base image: `linux/amd64` targets
  x86-64-v3, the AlmaLinux 10 baseline, and its glibc aborts with `CPU
  does not support x86-64-v3` on older CPUs such as the Intel Atom C2338.
  `linux/amd64/v2` (`x86_64_v2` RPMs, EPEL from AlmaLinux's AltArch
  rebuild) runs on those. containers/image (podman, bootc) doesn't
  detect x86-64 levels: on amd64 it always picks the entry without a
  variant, so v2 is only used when asked for (`podman run --platform
  linux/amd64/v2`). bootc has no such option: `bootc upgrade` and
  `bootc switch` always fetch `linux/amd64`. See "Known limits".

### Firewalld (both images)

- **`firewall-offline-cmd`'s zone-scoped removal option is
  `--remove-service-from-zone=<service>`.** Not `--remove-service`: that
  looks similar but is a separate, mutually exclusive legacy "lokkit"
  option ("Can't use lokkit options with other options"). Not
  `--delete-service` either: that deletes the global service
  *definition*, which fails for built-in services (`BUILTIN_SERVICE`)
  such as `ssh` or `cockpit`. The equivalent for a policy is
  `--remove-service-from-policy`.
- **`--check-config` validates zone/policy/ipset wiring, not ipset
  entries.** A policy referencing a missing ipset is caught
  (`INVALID_IPSET`); an invalid address in an ipset is silently ignored,
  and overlapping or empty ipsets are accepted. Anything that loads
  ipset entries from external data has to validate them itself; see
  `images/almalinux/geoblock.nu`.

### `images/cs-firewall-bouncer`

[cs-firewall-bouncer](https://github.com/crowdsecurity/cs-firewall-bouncer)
built from source (tag `v<BASE_VERSION>`), on `scratch`. It pulls the
bans of a CrowdSec Local API (LAPI) and drops those sources in nftables
tables `ip crowdsec` and `ip6 crowdsec6`, hooked at `input` and `forward`
with priority -10, before firewalld's chains. The LAPI (the security
engine that decides the bans) is not part of this repository.

- **An application image, not a bootc one.** The bouncer is one static Go
  binary: shipping it as a container keeps it out of the host image, gives
  it its own release cadence and rolls back by changing a tag. It has no
  `bootc container lint`: its last instruction is a smoke test, the
  binary run in exec form with `-T` (prints the merged config, no
  netlink, no capability). That `RUN` leaves empty `/dev`, `/proc` and
  `/sys` folders in the image: harmless, the runtime mounts over them.
  `scripts/build.sh` refuses it: there is no disk image to build.
- **`BASE_VERSION` is the bouncer release**, also the tag. The name is
  kept because CI reads the tag from it, as from a Dalec spec's
  `args.BASE_VERSION` (`build-apps.yml`). Renovate bumps it in the
  Containerfile; before merging, diff upstream's `config/crowdsec-firewall-bouncer.yaml`
  between tags.
- **The sources come from `ADD <git url>#v<BASE_VERSION>`.** The commit
  is not pinned: a tag can move, and this binary runs as root with
  `NET_ADMIN` in the host network namespace, so the build trusts upstream
  (buildah ignores `ADD --checksum` for git anyway). CI builds it with
  BuildKit, like the Dalec images; a local podman build runs the host's
  `git` for it, which a podman machine must have. The source has
  no `.git`, so the build passes `BUILD_VERSION` and `BUILD_TAG` to the
  Makefile.
- **Runtime contract (podman, rootful, documented in the
  Containerfile):** host network, root, `--cap-drop all --cap-add
  NET_ADMIN`, `--read-only`, `no-new-privileges`, and
  `--security-opt label=disable`: container-selinux's `container.te`
  grants `netlink_netfilter_socket` to the container runtime domain, not
  to `container_t`. A test on Fedora CoreOS (selinux-policy 42,
  enforcing) worked without it, so it's kept only so the bouncer doesn't
  depend on the policy version. `API_URL` and `API_KEY` come from the runtime (the key
  as a podman secret): no default LAPI, no key in the image. `scratch`
  has no CA bundle: plain HTTP to the LAPI only.
- **Config: `etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`**,
  the upstream RPM's path. Mount one override file at
  `<that path>.local`, which the bouncer deep-merges (maps merge,
  scalars and lists are replaced): the host's
  `/etc/crowdsec/firewall-bouncer.yaml`, mounted `:ro` without `:Z` (the
  container is unconfined, and relabeling a host `/etc` file is wrong).
  Only one file: `scratch` has no shell for a `.d/` wrapper. To replace
  the config, mount a file and append `-c <path>` (it replaces the image's `CMD`).
- **`retry_initial_connect: true`.** Without it, the bouncer exits (and
  deletes its tables) when the first pull fails: a crash loop at boot, or
  while a remote LAPI is down. Later errors are only logged and the bans
  stay.
- **Metrics** on `127.0.0.1:60601` of the host. **Kill switch:** stop the
  container (a graceful stop deletes the tables). Don't `nft delete
  table` while it runs: it doesn't recreate it.
- **Interaction with the host firewall:** its own tables, independent of
  firewalld (survives `firewall-cmd --reload`, nothing to open) and of
  almalinux's geo-blocking, which also drops (overlap is harmless). The
  admin's IP must be allowlisted on the LAPI, or a ban locks out sshd
  (port 42022).

### `images/sabnzbd`

[SABnzbd](https://sabnzbd.org) (Usenet downloader, Python), built with
[Dalec](https://project-dalec.github.io/dalec/) from
`images/sabnzbd/spec.yml`: no Containerfile. Dalec builds one Debian
trixie package (the app, its Python modules, par2cmdline-turbo), then the
`trixie/container` target installs it into an image built from scratch
out of the package's dependency closure (python3.13, unrar, 7zip, libc,
…).

- **Dalec, not a Containerfile on distroless.** The image keeps a dpkg
  database, so scanners see every Debian package and its version, and
  is about as small as distroless: no shell, no apt (dpkg stays). A
  distroless base (`gcr.io/distroless/*`) can't be used: Dalec installs
  the package with dpkg, and distroless has no `/var/lib/dpkg/status`
  (base-files' postinst fails).
- **Only `docker buildx` builds it** (Dalec is a BuildKit frontend, the
  spec's `# syntax=` line; buildah ignores it): `docker buildx build -f
  images/sabnzbd/spec.yml --target trixie/container images/`, and CI's
  `build-apps.yml`. `scripts/build.sh` refuses it (no Containerfile).
- **Sources pinned by commit**: Dalec checks that the sabnzbd and
  par2cmdline-turbo tags resolve to the commits in the spec.
- **Python modules from PyPI, not Debian**: Debian's are older than
  SABnzbd requires (sabctools 8.2 for 9.6). `requirements.lock` is
  upstream's `requirements.txt` without notify2 (desktop notifications),
  every module pinned with its hashes; the build installs it with uv
  (`--require-hashes`, the only network access of the build), into
  `/usr/lib/sabnzbd/site-packages`, found through a `.pth` file. Bytecode
  is compiled at build time (`unchecked-hash`: the user can't write
  `/usr/lib`, and dpkg clamps mtimes). Regenerate it with
  `scripts/sabnzbd-lock.sh` on every bump, or to update unpinned modules
  (cryptography).
- **par2cmdline-turbo built from source**, SABnzbd's recommended par2:
  trixie only has par2cmdline 0.8.1. unrar comes from trixie's
  `non-free` (only when building the image, not the package).
- **Licenses kept in `/usr/share/doc`**: par2cmdline-turbo's `COPYING`
  (GPL-2.0, ships with the binary) is a `licenses` artifact. Declaring one
  makes `trixie/container` keep the whole tree, so the Debian packages'
  `copyright` files stay too (about 4 MB with their docs and man pages);
  without it Dalec deletes all of it.
- **7za through `/usr/local/bin/7za`**, a symlink to
  `/usr/lib/7zip/7za`: Debian's `/usr/bin/7za` is a shell script.
  The spec's tests run every tool from the path SABnzbd finds.
- **Downloads in `/downloads/{incomplete,complete}`**, patched into
  SABnzbd's defaults (`downloads-dir.patch`): otherwise they default to
  `Downloads/` next to `sabnzbd.ini`, in `/config`, and there is no CLI
  option or variable to change them. Check the patch on every bump.
- **Runtime contract:** UID/GID 65532 (no passwd entry, `HOME=/config`),
  `/config` (settings, queue, logs) and `/downloads` writable by it, web
  UI on 8080/tcp. Reaching it by a host name other than an IP or
  `localhost` needs that name in SABnzbd's `host_whitelist` (Config →
  Special). At start SABnzbd prints `Exception in isFAT(...): ... 'df'`:
  harmless, only a FAT warning check. No shell, no `/usr/bin/env`, no
  `nice`/`ionice`: post-processing scripts must be Python, executable,
  with `#!/usr/bin/python3` or no shebang (SABnzbd then runs them with
  its own Python); upstream's `Sample-PostProc.sh` can't run.
- **`BASE_VERSION` is the SABnzbd release**, also the tag. Renovate
  bumps it in the spec (with the sabnzbd checksum), where
  `build-apps.yml` reads it; push the regenerated lock to its PR.

### `images/nftables-exporter`

[nftables-exporter](https://github.com/metal-stack/nftables-exporter)
(Prometheus metrics of the host's nftables counters, sets, chains and
rules, Go), built with Dalec from `images/nftables-exporter/spec.yml`, as
`images/sabnzbd` (same reasons, same `docker buildx` build). One Debian
trixie package, the exporter, installed with Debian's `nftables`.

- **Not a static binary on scratch**, unlike cs-firewall-bouncer: the
  exporter runs `nft -j -t list ruleset` on every scrape, and nft needs
  its libraries. trixie's nftables (1.1.3) is enough: set `count`
  metrics need nft 1.1.7 and an unreleased exporter.
- **Go from trixie-backports**, only for the build (`extra_repos` with
  `envs: [build]`): trixie's golang-go is 1.24, the exporter's `go.mod`
  and modules need 1.26. Renovate follows backports' golang-go through
  Repology (its deb datasource can't read backports' `Packages.xz`).
  Go modules are downloaded before the build by Dalec's `gomod`
  generator, pinned by `go.sum`.
- **Only native builds**: a cross build (`--platform` another
  architecture, through QEMU) fails in the `gomod` generator with `exec:
  "sh": executable file not found in $PATH` (Dalec 0.22 runs it in the
  build platform's root filesystem without its `PATH`). CI builds each
  platform on its own runner.
- **Config in `/etc/nftables_exporter.yaml`**
  (`nftables_exporter.yaml`), the exporter's default `--config`, without
  which it exits: listens on `127.0.0.1:9630` instead of upstream's
  `:9630`, as it runs in the host network and the rules (comments,
  addresses, ports) would be on every interface; `nft` at Debian's
  `/usr/sbin/nft`. Mount another file over it to change it.
- **Runtime contract (Kubernetes DaemonSet):** `hostNetwork: true`
  (rules belong to a network namespace), root with `NET_ADMIN` as only
  capability (drop ALL, `allowPrivilegeEscalation: false`, read-only
  root filesystem), no volume. Root because nft reads the ruleset over
  netlink with `CAP_NET_ADMIN`, and a non-root process loses it when it
  runs nft: only ambient or file capabilities survive an exec, Kubernetes
  can't set ambient ones, and file ones need `allowPrivilegeEscalation`.
  Checked: as UID 65532 with `NET_ADMIN`, `nftables_up` is 0.
- **Loopback, so probes and scrapes need care:** probes need `host:
  127.0.0.1` (the kubelet probes the pod IP, the node's). Prometheus
  can't reach loopback from another node: put an authenticating TLS proxy
  in the pod (kube-rbac-proxy on the node's IP, upstream
  `http://127.0.0.1:9630/`), or set `bind_to` to the node's IP and filter
  the port on the host (NetworkPolicies don't apply to host network pods
  with most CNIs).
- **Upstream's unit tests run in the build** (`go test ./...`, no network
  or nft needed): with the spec's tests, the only check of an automerged
  Go update.
- **`BASE_VERSION` is the exporter's tag** without its `v` (upstream
  publishes no GitHub releases). Renovate bumps it with the source
  checksum; check upstream's `options.go` for new options.

### `images/jellyfin`

[Jellyfin](https://jellyfin.org) (media server, C#/.NET), server only,
built with Dalec from `images/jellyfin/spec.yml`, as `images/sabnzbd`
(same reasons, same `docker buildx` build). One Debian trixie package,
the server, installed with `jellyfin-ffmpeg8`.

- **Repackaged, not built from source**: the package copies
  `/usr/lib/jellyfin/bin` from upstream's `jellyfin-server` deb
  (Jellyfin's trixie repository, an `extra_repos` with its key pinned by
  digest). trixie has no .NET SDK and Dalec no NuGet generator, so a
  source build would download the SDK and every NuGet package unpinned
  (upstream has no `packages.lock.json`). The deb is a build dependency
  pinned to `${BASE_VERSION}+deb13`: its maintainer scripts (bash,
  `adduser`) run in the build container, never in the image, and the
  same pin works for both architectures. Upstream's binaries are kept as
  is (`disable_strip`: their own build can't strip `libpdfium.so`).
- **`jellyfin-ffmpeg8` from the same repository, not pinned** (like
  Debian's packages, the weekly rebuild picks up its fixes): the ffmpeg
  fork Jellyfin needs, bundling its hardware drivers: Intel (amd64:
  VA-API, QSV, Vulkan), AMD (VA-API, Vulkan), Rockchip (arm64: MPP,
  RGA). Not added: Intel OpenCL (`intel-opencl-icd` isn't in trixie,
  upstream's Docker image installs GitHub debs, amd64 only; HDR tone
  mapping on Intel falls back to VPP) and Rockchip's libmali.
- **No web client** (`--nowebclient`): clients are the apps (Android,
  TV) and Seerr. jellyfin-web would need Node.js 24 to build, trixie
  has 20. The first-run wizard is done through the API (`/Startup`) or a
  client that runs it.
- **Upstream's Docker layout**: data in `/config`, cache in `/cache`,
  `LD_PRELOAD` of jemalloc (as upstream's deb and image), CJK fonts
  (posters and burnt-in subtitles), NVIDIA capabilities including
  `video` (NVENC/NVDEC).
- **Temporary files in `/cache`** (`TMPDIR`): the root filesystem can be
  read-only, and Docker and Kubernetes mount no tmpfs on `/tmp` (Podman
  does). Without it, ASP.NET's key ring writes fail (`Read-only file
  system : '/tmp/'`). On disk rather than in memory: Jellyfin extracts
  attachments and subtitles there.
- **Runtime contract:** UID/GID 65532 without a passwd entry (`HOME` is
  `/config`), `/config` and `/cache` writable by it, media read-only,
  read-only root filesystem possible. `/cache` is rebuilt as needed: on
  Kubernetes, an `emptyDir` on disk (not `medium: Memory`, transcodes
  are large). 8096/tcp (API), 7359/udp (client discovery, same network
  only). Probes: `GET /health` on 8096 (`Healthy`). Hardware
  transcoding: `/dev/dri` (Rockchip: also `/dev/mpp_service`,
  `/dev/rga`) with the devices' GID as a supplementary group, or the
  NVIDIA Container Toolkit.
- **Tests**: ffmpeg and ffprobe run, and the server starts with `--mode
  MigrateSystem` (.NET runtime, SQLite, plugins, an empty database's
  migrations, then exit 0). Not `--version`: it exits 1.
- **`BASE_VERSION` is the server's release**, followed by Renovate in
  the repository's `jellyfin-server` package (deb datasource), not in
  GitHub's tags: a PR only comes once the package exists. Never
  automerged: a release migrates the database for good, back up
  `/config` first. The repository key's digest isn't followed: if
  upstream rotates it, the build fails on the digest.

## Design decisions

- **The build context is the shared `images/` folder, not each image's
  own folder.** `scripts/build.sh` passes `-f images/<name>/Containerfile`
  with context `images/`. This is what lets
  `images/almalinux/Containerfile` do `COPY --link ./fedora/sysroot/common/ /`
  to reuse fedora's base configuration instead of duplicating it. Each
  image's own files live in `images/<name>/sysroot/`, which mirrors the
  root filesystem. A bootc image's `sysroot/` has a `common/` folder,
  then a folder per base release (`sysroot/<BASE_VERSION>/`), copied
  after it, for the files that differ (`policy.json`): almalinux builds
  9 and 10 from one Containerfile, and a base upgrade adds a folder
  instead of editing the one the running release uses. One
  `.containerignore` at `images/` (buildah only reads it from the
  context root, or through `--ignorefile`) keeps every
  `Containerfile` out of `COPY . /`; there is no need for a copy per
  image folder.
- **`COPY` rather than `ADD`.** `ADD` also downloads URLs and unpacks
  archives, which we don't want for plain files. Exception:
  `images/almalinux`'s build-only `geoblock` stage uses `ADD <url>` on
  purpose, for its content-digest build cache.
- **Content goes in `/usr`, `/var` stays empty.** When deployed, `/usr` is
  read-only and replaced on every update. `/etc` is merged three ways on
  update. `/var` is machine-local state, copied from the image only at the
  first install, so anything left there in the image never updates.
  Packages and static config therefore go in `/usr`, `/etc` only when the
  config must be machine-local, and nothing in `/var`.
- **`COPY` comes after the package install.** Editing config files doesn't
  force dnf to run again on rebuild.
- **The base image is pinned to a major release, `ARG BASE_VERSION`.**
  `latest` would jump to the next Fedora release without warning. The
  same value is the image's own tag, so a host tracking
  `images/fedora:<version>` gets every rebuild through `bootc upgrade`,
  and only moves to the next release with `bootc switch`. The Containerfile default
  is for local builds; CI passes it from its matrix.
- **`bootc container lint` without `--fatal-warnings`.** Errors fail the
  build, warnings are only printed.
- **hadolint on every Containerfile**, application images included
  (`.hadolint.yaml`). DL3041 (pin dnf package versions) is ignored:
  packages follow the pinned base release, like the base image does.
- **One `RUN <<EORUN` heredoc with `set -xeuo pipefail`.** It gives one
  layer without `&& \` chains. `-e` is required because a heredoc `RUN`
  only fails on the exit status of its last command. Heredocs need
  buildah 1.33 or later.

## Disk images: image-builder

`scripts/build.sh` runs a pinned `ghcr.io/osbuild/image-builder-cli`
(which includes the former bootc-image-builder) with:

- **`--privileged` and `--security-opt label=type:unconfined_t`:**
  image-builder relabels files for SELinux and sets up loop devices. A
  confined container fails with `chcon: ... Permission denied`.
- **`-v /var/lib/containers/storage:/var/lib/containers/storage`:**
  image-builder never pulls the bootc image. It reads it from the host's
  rootful storage. Without this mount it tries to pull the tag from
  ghcr.io instead of using the image just built.
- **Rootful podman:** image-builder checks for it. On macOS use
  `podman machine set --rootful`. The podman client then talks to the
  rootful machine, so `sudo` isn't used.
- **`--blueprint /config.toml`:** user accounts and SSH keys are added only
  to the disk image, never baked into the container image. The file is an
  [osbuild blueprint](https://osbuild.org/docs/user-guide/blueprint-reference/)
  (check each option's bootc tab). It holds credentials, so it is
  git-ignored and `config.example.toml` is the template.
- **`--output-dir <name> --output-name <name>`:** gives a fixed path,
  `output/<name>/<name>.qcow2`. The default name depends on the distro and
  architecture.

Images are tagged `ghcr.io/spnngl/images/<name>:<version>`,
`<version>` being the Containerfile's `ARG BASE_VERSION` default: the
same name CI pushes for the default target, so an installed host upgrades
from CI's images. `build.sh` only builds the default target
(`dockerenv`) and never pushes.

## CI: `.github/workflows/build-bootc.yml`

Runs hadolint on each bootc Containerfile (findings uploaded to code
scanning as SARIF), then builds each image of its matrix (`name`, `version`, and
for a multi-stage Containerfile `target`, tag `suffix` and, for
kubeenv, `k3s`) for every platform, and pushes it to
`ghcr.io/spnngl/images/<name>:<version><suffix>`, one manifest list
for all platforms, authenticated with the job's `GITHUB_TOKEN` (`packages: write`).
Container images only: disk images need `config.toml`.

- **Triggers:** push to `main`, every Sunday 07:00 Europe/Paris (base
  image and package updates, fresh almalinux geo-blocking data) and
  manual dispatch all push. Pull requests only lint and build. Pushes
  and pull requests only run it when a bootc image's input changed
  (`paths`: `images/fedora/`, `images/almalinux/`, `images/k3s/`, the
  files at the root of `images/`, the workflow), and then rebuild every
  bootc image: they share most of their files, and one rule is simpler
  than tracking which folder each Containerfile reads. A failed push is
  retried by the next bootc change or the weekly rebuild.
- **The matrix is the list of images**, each with its base version,
  passed as `--build-arg BASE_VERSION`. A new bootc image goes there
  too, and in `paths`; Renovate bumps the versions. The `push` job
  reuses it through a YAML anchor.
- **Jobs run on `ubuntu-26.04` and `ubuntu-26.04-arm`, not
  `ubuntu-latest`.** They ship Podman
  5.7 / Buildah 1.42; `ubuntu-latest` (24.04) has buildah 1.33, and the
  Containerfiles use `COPY --link` (buildah 1.41+). Builds use the
  runner's rootless podman, where `build.sh` uses rootful podman.
- **Same `podman build` flags as `build.sh`** (`--format=docker`, context
  `images/`), plus an `org.opencontainers.image.source` label that links
  the ghcr.io package to the repository, and `--platform` set to the
  runner's own.
- **Each platform builds natively, on its own runner:** no QEMU, so
  arm64 builds as fast as amd64, in parallel. Each build downloads
  almalinux's geo-blocking data itself, so the data can differ slightly
  between platforms.
- **A `push` job per image merges its platforms:** each build job saves
  its image as a `dir:` transport folder with gzipped layers
  (`podman save --format docker-dir --compress`; OCI would drop `SHELL`),
  uploaded as an artifact kept one day. The `push` job adds every
  platform's folder to one manifest list, and fails if one is missing rather than push a
  partial list. It runs even when another image's build failed, so one
  broken image doesn't hold back the others. Pull requests build every
  platform but upload nothing.
- **Pushed images are signed**, then pulled back with the image's own
  `policy.json` to check the signature. See "Signing".
- **Pull requests scan every image** for vulnerabilities. See
  "Vulnerability scanning".

## CI: `.github/workflows/build-apps.yml`

The same for application images, Dalec and Containerfile ones: same
triggers, runners and tags as `build-bootc.yml`, Docker tooling only (no
podman: it can't run Dalec, and one way to build, attest and sign every
application image is simpler). The differences:

- **Images are found, not listed**: a `discover` job makes the matrix
  from every `images/<name>/spec.yml` and every `images/<name>/Containerfile`
  that doesn't run `bootc container lint` (a bootc image's), its
  version being the spec's `args.BASE_VERSION` (read with `yq`) or the
  Containerfile's `ARG BASE_VERSION` default. A new application image
  needs no workflow change.
- **Only the images that changed**: those whose folder changed, or
  every one when a file at the root of `images/` or the workflow
  changed, or on the weekly rebuild and manual runs. Changed since what:
  a pull request's base, or for a push the workflow's last successful
  run on the branch, not the previous push: a run cancelled by a newer
  one (`concurrency`) or failed never pushed its images, so the next run
  builds its changes too. No successful run to compare with: every
  image.
- **hadolint for the Containerfiles to build**, as in `build-bootc.yml`.
  Code scanning keeps the others' alerts from their last analysis.
- **`docker/build-push-action`**, with a `docker-container` builder
  (the docker driver can't add attestations). Building also runs the
  spec's tests, or the Containerfile's smoke test, on each platform. A
  Containerfile sets its own `org.opencontainers.image.source` label, as
  a spec does: no `--label` here.
- **Attestations from BuildKit**
  (<https://docs.docker.com/build/metadata/attestations/>), in each
  platform's index: SLSA provenance (`mode=max`, `version=v1`: also the
  build args; no secrets) and an SPDX SBOM. BuildKit's syft scanner
  runs on the final image whatever the frontend, so it lists the Debian
  packages (dpkg database), the Python ones (`dist-info`) and a Go
  binary's modules.
  Read them with `docker buildx imagetools inspect <tag> --format
  '{{ json .Provenance }}'` (or `.SBOM`). No
  `actions/attest-build-provenance`: it would be a second provenance.
- **Each build job pushes its platform by digest**, untagged, and hands
  the digest over; the `push` job merges them into the tagged list with
  `docker buildx imagetools create`, attestations included.
- **Signed by `cosign sign`**, with the same key and in the same
  attachment format as podman's (see "Signing"), then checked with
  `cosign verify`.
- **Pull requests scan every image**, from an extra OCI layout output:
  the `image` one is neither pushed nor loaded then. See "Vulnerability
  scanning".

## Vulnerability scanning

spnngl/.github's `scan-image` action runs Grype and Trivy on an image.
Both: Trivy has no Fedora vulnerability data (it skips the packages of
`images/fedora`), Grype has; their other sources differ too.

- **Pull requests:** each build job scans its image and platform (an
  OCI layout: `podman save --format oci-dir`, buildx `type=oci`), and
  fails on a Critical vulnerability with a fix. Without a fix, nothing
  a pull request can do: reported, not failed.
- **Pushed images:** `image-scan.yml` scans them daily, as a new
  vulnerability shows up without any change here, and uploads the High
  and Critical findings to code scanning. It never fails, nor do the
  builds of `main` and the weekly rebuilds: failing them would keep the
  older image, with more vulnerabilities, on the hosts. It scans the
  tags pushed in the last 8 days, every platform of each: the weekly
  rebuilds cover the current ones, older tags are no longer rebuilt.
- **False positives:** `.grype.yaml` (`ignore:` rules) and
  `.trivyignore.yaml`, at the repository root, with the reason for each.

## Updates: `renovate.json5`

[Renovate](https://docs.renovatebot.com/) opens PRs every Saturday, the
day before the weekly rebuild, for every pinned version: base images,
k3s, application and build-tool releases, the scripts' and docs'
images, GitHub Actions. `.github/workflows/renovate.yml` validates the
config with the shared workflow of
[spnngl/.github](https://github.com/spnngl/.github), which also holds
the Renovate preset this config extends (timezone, labels, semantic
commits, action digests, automerge under `.github/`).

- **One PR per dependency, every file at once:** a version pinned in
  several places (Containerfile `ARG`, workflow matrix, spec args with
  their source checksum) has a custom regex manager per place, under the
  same dependency name, so they land in one PR. A new pin needs one too,
  or it goes stale silently. Values derived from a version are rewritten
  with it, in the same replacement (`autoReplaceStringTemplate`): the
  kubeenv `suffix` from the matrix's `k3s` on the next line.
- **Major base releases:** `BASE_VERSION` is the base image's major tag
  (`44`, `10`), which the weekly rebuild follows through point releases.
  Renovate only proposes the next major release.
- **3 days before a GitHub release or tag is proposed** (actions, k3s,
  upstream sources, `minimumReleaseAge`): time for a broken or malicious
  release to be pulled, and for CRI-O to publish a new Kubernetes minor
  release. Not for images: Renovate only gets their release dates from
  Docker Hub, and holds an update without one.
- **Release tags, no digests**, except for actions (pinned to a commit,
  automatically). A digest on `FROM` would freeze the base image between
  weekly rebuilds, and Renovate would write it into `ARG BASE_VERSION`,
  which is also the image's tag.
- **Fedora releases come from endoflife.date**, not from the image's tags:
  `quay.io/fedora/fedora-bootc` tags the branched release and rawhide with
  their number before they are released. AlmaLinux 9 is never moved to
  10 (kept for x86-64-v2 hosts).
- **Automerged once CI passes:** actions (one grouped PR), k3s builds
  and Kubernetes patch and minor releases, and minor and patch releases
  of the build tools CI exercises (golang, nushell, Dalec frontend,
  par2cmdline-turbo) or the docs only use (hadolint, Renovate's
  validator). A Kubernetes minor release fails CI until CRI-O publishes its
  repository for it (`images/k3s/install.sh`): re-run the PR's checks then.
- **Reviewed by hand**, each PR saying what to check: base images (CI
  fail until their `sysroot/<BASE_VERSION>/` is added, see "Signing"),
  SABnzbd and uv (regenerate the lock), cs-firewall-bouncer and
  nftables-exporter (port upstream's config changes), Jellyfin (database
  migrations), image-builder-cli,
  and every major
  release.
- **A new base major or Kubernetes minor release changes the image
  tag**: hosts stay on the old one, which is no longer rebuilt, until
  `bootc switch`.

## Signing

CI signs every image it pushes with a cosign key pair; hosts refuse
`ghcr.io/spnngl/images/*` images without that signature. Local
builds are not signed: `build.sh` never pushes, and a host installed from
a local build upgrades from CI's signed images.

- **Keys:** the private key is the `COSIGN_PRIVATE_KEY` repository secret,
  never in git. It has no passphrase (CI passes an empty one).
  With one, add a secret and write it to the `--sign-passphrase-file`. The public key is
  `images/fedora/sysroot/common/usr/share/pki/containers/spnngl-images.pub`,
  in `/usr` so that it updates with the image.
- **`podman push --sign-by-sigstore-private-key`, not `cosign sign`.**
  bootc verifies through containers/image (skopeo), which reads sigstore
  signatures as `sha256-<digest>.sig` attachments only. cosign 3 stores
  them by default as a sigstore bundle behind OCI referrers, which
  containers/image can't see. podman writes the attachment format and
  takes cosign keys (`ENCRYPTED SIGSTORE PRIVATE KEY`). No Rekor
  transparency log entry is made; the policy doesn't ask for one.
  Application images, built without podman, use `cosign sign` with cosign 3's
  deprecated legacy flags, which write the same attachments
  (`build-apps.yml` explains each flag). `--sign-container-identity`
  makes it claim the tag, as podman does: otherwise a tag pull is
  rejected.
- **Not keyless**: containers/image's policy matches a Fulcio
  certificate by email only (`subjectEmail`,
  `image/signature/fulcio_cert.go` in
  `github.com/containers/container-libs`), and a GitHub Actions
  certificate carries the workflow's URL, not an email.
- **`etc/containers/registries.d/spnngl-images.yaml`** turns on
  `use-sigstore-attachments` for our namespace: needed to read the
  signatures on hosts, and to write them in CI.
- **`etc/containers/policy.json`, one per image and base release**
  (`sysroot/<BASE_VERSION>/`; AlmaLinux 9's differs from 10's: GPG keys
  for Red Hat's registries, 10 uses sigstore): the base image's file,
  plus `"default": reject` (below) and a `sigstoreSigned` requirement
  for `ghcr.io/spnngl/images`. It replaces the file shipped by
  `containers-common`, since `policy.json` has no drop-in directory.
  When a base image changes its `policy.json`, port the change: before
  replacing it, the Containerfiles check with `images/fedora/policy.jq`
  that ours is still the base's plus those changes, and fail the build
  otherwise. A new base release fails it until its folder is added; so
  does a change within a release, at the weekly rebuild.
- **`"default": reject`** is what `enforce-container-sigpolicy = true`
  (`usr/lib/bootc/install/50-rootfs.toml`) requires: bootc refuses to pull
  when the default is `insecureAcceptAnything`. Every transport, and every
  other registry, still accepts anything as before, so podman keeps working
  (`containers-storage` is also how image-builder installs a local build).
- **Rotating the key:** ship the new public key alongside the old one
  (`keyPaths`), let hosts upgrade, then switch the CI secret and run
  both build workflows by hand: a push only re-signs what it rebuilds.
- **Build provenance, on top:** `actions/attest-build-provenance`
  attests which workflow, commit and run built each manifest list. It is
  a sigstore bundle behind OCI referrers, like cosign 3's, so hosts
  don't read it: the signature above is what they check. Check it with
  `gh attestation verify oci://ghcr.io/spnngl/images/<name>:<tag> -R spnngl/images`.
  The action only reads Docker's credential file, so CI logs podman in
  with `REGISTRY_AUTH_FILE=~/.docker/config.json`. Application images carry
  BuildKit's provenance and SBOM instead (`build-apps.yml` section).

## Running: `scripts/run.sh`

QEMU with HVF acceleration, the `virt` machine and the Homebrew aarch64 UEFI
firmware. The serial console is in the terminal (`Ctrl-a x` quits) and SSH
is forwarded from `localhost:${SSH_PORT:-2222}` to the guest sshd port
42022, set by `images/fedora`. `-snapshot` throws away
disk changes on exit.

It only supports macOS on Apple Silicon, and says so when run anywhere else.

## Known limits

- `run.sh` only supports macOS on Apple Silicon.
- Only qcow2 is built. For other formats, change the image type in
  `build.sh` (for example `anaconda-iso`, `raw`, `vmdk`).
- `build.sh` builds for the host architecture only. Building for x86_64
  on an arm Mac needs `podman build --platform linux/amd64` and a target
  architecture option for image-builder. This is experimental and
  emulated, so slow.
- **almalinux on x86-64-v2 CPUs (e.g. Intel Atom C2338):** install with
  `podman run --platform linux/amd64/v2 ...`. `bootc upgrade` then
  fetches `linux/amd64`, the x86-64-v3 build, and the new deployment
  won't boot (pick the previous one in GRUB, or `bootc rollback`).
  Upgrades on such hosts need a tag that points at the v2 build only.
- **cs-firewall-bouncer and the `kubeenv` images:** Cilium runs with
  `kubeProxyReplacement=true` (K3S.md), which handles NodePort and
  LoadBalancer traffic in eBPF before netfilter: the bouncer doesn't
  cover it. It covers the host's own services (sshd, the k3s API,
  hostNetwork pods).

## References

- bootc docs: <https://bootc.dev/bootc/> (source: `bootc-dev/bootc`, `docs/src`)
- Fedora bootc examples: <https://gitlab.com/fedora/bootc/examples>
- image-builder: <https://github.com/osbuild/image-builder>
  (bootc-image-builder now lives in `bootc-image-builder/` there)
- Build config: <https://github.com/osbuild/image-builder/blob/main/bootc-image-builder/README.md#-build-config>
- Renovate: <https://docs.renovatebot.com/> (source: `renovatebot/renovate`)
