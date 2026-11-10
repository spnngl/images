# fedora-coreos: references

## Sources

Read each at the version this repository pins.

- Base image: <https://quay.io/repository/fedora/fedora-coreos?tab=tags>;
  `github.com/coreos/fedora-coreos-config` (`manifests/`, `overlay.d/`,
  `manifest-lock.<arch>.json`: what the base ships)
- Disk images: `github.com/coreos/custom-coreos-disk-images`
  (`README.md`, `custom-coreos-disk-images.sh`,
  `cosa-imports/coreos.osbuild.x86_64.mpp.yaml`), the osbuild stage it
  deploys with: `github.com/osbuild/osbuild`
  (`stages/org.osbuild.ostree.deploy.container`), which runs bootc's
  `ostree-container`
- Kernel arguments: bootc's `crates/lib/src/bootc_kargs.rs` (kargs.d on
  upgrade), `crates/ostree-ext/src/container/deploy.rs` and
  `crates/lib/src/install/completion.rs` (kargs.d on a disk's first
  deployment); <https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html>,
  `Documentation/admin-guide/LSM/` (lockdown: `security/lockdown/`), and
  the base kernel's `/usr/lib/modules/<version>/config` for its defaults
- Kubernetes packages: `https://pkgs.k8s.io/core:/stable:/v<minor>/rpm/`
  (kubelet, kubeadm, kubectl, cri-tools, kubernetes-cni)
- Node settings being ported from the previous node images (Ubuntu, called
  `capi-image-builder` below): `github.com/kubernetes-sigs/image-builder`
  (`images/capi/ansible/roles/{containerd,kubernetes,node,sysprep}/`)
- Cluster API: `github.com/kubernetes-sigs/cluster-api`
  (`bootstrap/kubeadm/pkg/ignition/clc/clc.go`, `kubeadmconfig_controller.go`)
- The bootstrap webhook: `github.com/spnngl/ignition-converter`
  (`README.md`, `deploy.yaml`), on `github.com/coreos/ign-converter`
  (`translate/v23tov30`)
- `github.com/fedora-iot/greenboot-rs` (`README.md`, `greenboot-rs.spec`,
  `usr/`)
- `github.com/bootc-dev/bootc-operator` (`api/v1alpha1/`,
  `internal/controller/rollout.go`)
- OpenSCAP: `github.com/OpenSCAP/openscap` (`utils/oscap-im`,
  `src/OVAL/probes/oval_fts.c`) and its content, scap-security-guide:
  `github.com/ComplianceAsCode/content` (`products/fedora/profiles/cis.profile`,
  `controls/cis_fedora.yml`, each rule's `rule.yml` and `oval/`), at the
  versions of the base's
  packages
- `github.com/SSSD/sssd` (`src/man/sssd.conf.5.xml`)
- grype: `github.com/anchore/grype` (`grype/presenter/models/`: its JSON;
  `grype/match/ignore.go`, `grype/vulnerability_matcher.go`: ignore rules),
  its database's Fedora data: `github.com/anchore/vunnel`
  (`src/vunnel/providers/fedora/`), at the version of Fedora's package
- The GPU image: NVIDIA's repositories
  (`https://developer.download.nvidia.com/compute/cuda/repos/fedora44/x86_64/`,
  `https://nvidia.github.io/libnvidia-container/stable/rpm/`: the packages'
  requirements are in each `repodata/*-primary.xml.gz`),
  `github.com/NVIDIA/gpu-operator`, `github.com/NVIDIA/nvidia-container-toolkit`,
  `github.com/NVIDIA/open-gpu-kernel-modules`, and
  `github.com/coreos/fedora-bootc-nvidia`
- Shared bootc sources: `bootc/REFERENCES.md`

## Decisions

### Base and Kubernetes

- **Base `fedora-coreos`, stable stream (`<major>.<date>.3.<n>`):** Ignition,
  Afterburn, coreos-installer, containerd, runc, bootupd and bootc are
  already in it; cri-tools, kubernetes-cni, greenboot and qemu-guest-agent
  aren't. Renovate proposes its stable releases only: the tags also hold the
  `testing` (`.2.`) and `next` (`.1.`) streams.
- **containerd from the base:** the runtime of `capi-image-builder`, updated
  with the base. Our config is `/usr/lib/containerd/config.toml` (version 3,
  imports `conf.d/*.toml` from `/usr/lib` then `/etc`), selected by
  `containerd.service.d/20-config.conf`: the package's `/etc` file stays
  untouched and the whole config is image content. `cri-base.json`
  (`RLIMIT_NOFILE` 65535) and the pause image (`20-pause.toml`) are
  generated at build, from `ctr oci spec` and
  `kubeadm config images list`, so they can't drift from the versions
  installed.
- **Kubernetes RPMs from `pkgs.k8s.io`, one patch release:** signed repo;
  ships `kubelet.service` and the kubeadm drop-in. The repo file is removed
  in the same `RUN`. `kubernetes-cni` ships `/opt/cni/bin`, which is
  `/var/opt` here: removed in that `RUN`, since `/var` ships empty.
- **Tag `<major>-v<minor>`** (`versions.sh`, e.g. `44-v1.35`), as CI's
  other images: a Fedora CoreOS release or a Kubernetes patch release
  reaches the nodes with `bootc upgrade`; a new major or Kubernetes minor
  is a new tag (`bootc switch`, or new machines through Cluster API).
  `kubelet` and `kubeadm` then move to the new patch release under Cluster
  API's `spec.version`, which `kubeadm upgrade` follows. `kubeadm init`
  without `--kubernetes-version` takes the newest patch release of the
  series, which may not be in the image: pass the version.
- **One image:** kubeadm nodes only, no k3s, no Docker. Replaces the
  `base`/`kubeenv`/`dockerenv` scheme of `bootc/AGENTS.md`; its stages
  are layers of the one image ("Layers", below).
- **Removed `zincati`, `moby-engine`, `docker-cli`:** updates come only from
  Cluster API or bootc-operator; containerd is the runtime.
  `bootc-fetch-apply-updates.timer` and `rpm-ostreed-automatic.timer` stay
  disabled. No `dnf autoremove`: it would take containerd with it. No weak
  dependencies, as FCOS itself is built.
- **`rpm-ostree-countme.timer` kept, as the base enables it:** each node
  counts in Fedora's count of systems, which sends no identifier (a
  `countme` bucket in the repository metadata requests, at most weekly:
  https://fedoraproject.org/wiki/Changes/DNF_Better_Counting).
- **No host firewall, nftables only:** Cilium filters (host policies), so
  `iptables-services` is removed and FCOS has neither firewalld nor ufw.
  `iptables` itself stays, a dependency of kubelet, bootc and podman: it is
  `iptables-nft`, which writes nf_tables. The legacy x_tables tables
  (`ip_tables`, `ip6_tables`, `arp_tables`, `ebtables`) can't load
  (`modprobe.d/blacklist.conf`, `install … /bin/false`), so no tool can add
  rules that `nft list ruleset` doesn't show.
- **Hardening kernel arguments in `usr/lib/bootc/kargs.d/`:** how an
  image sets its command line; bootc has no `kargs` command, and applies
  the files' changes on upgrade. Some are already the kernel's defaults (each file says which),
  stated so a config change of Fedora's doesn't undo them.
  `lockdown=integrity` has a file of its own, `10-lockdown.toml`: an image
  that loads unsigned modules deletes it, and bootc drops the argument
  from the nodes that switch to it. `test/system/node.yaml` expects `[integrity]`
  or `[none]` by the image's own kernel arguments.
  **`lockdown=integrity`, not `confidentiality`:** confidentiality also
  blocks kprobes, tracefs, perf and BPF reads of kernel memory, which
  Tetragon and Falco need. Tried on a sandbox control plane, Cilium 1.20
  kept working under confidentiality, but systemd's `RestrictFileSystems=`
  BPF program and systemd-nsresourced's user namespaces stopped; integrity
  blocks none of these (`include/linux/security.h`, `enum
  lockdown_reason`). `init_on_free=1` costs a few percent of CPU on
  allocation-heavy work.
- **Disk images get kargs.d from bootc:** osbuild's
  `org.osbuild.ostree.deploy.container` runs `ostree container image
  deploy`, which is bootc (`ostree-container`); since bootc 1.17 it adds the
  image's kargs.d (`bootc internals bootc-install-completion`). Passing
  them again as `--extra-kargs` wrote each one twice on the command line.
- **SELinux permissive** (`/etc/selinux/config`): containerd runs with
  `enable_selinux = false`, as in `capi-image-builder`; kept from those
  nodes, against FCOS' advice (`docs/selinux.adoc`: enforcing, or a per-domain
  permissive module). It still labels and logs denials.
- **Versions not pinned:** containerd and runc (the base's) and cri-tools
  (the newest of the Kubernetes minor's repository), unlike
  `capi-image-builder`'s; they move with `BASE_VERSION` and are tested by
  the build check.
- **Ubuntu-isms not ported:** `rp_filter` stays Fedora's (loose, 2; Cilium
  needs loose), `prips` has no Fedora package and no user, no
  `etcd-client` (see No `etcd` package, under Vulnerabilities). Bare-metal kernel arguments come from Ignition
  (Later).
- **`/opt` is a symlink to `var/opt`** (already in the base): nothing in
  `/opt` comes from the image.
- **No preloaded images:** `/var` is filled at install only and never
  updated afterwards, and every node reaches the registries. docker.io pulls try public mirrors first
  (`etc/containerd/certs.d/docker.io/hosts.toml`): `mirror.gcr.io`, then
  `public.ecr.aws/docker` (official images only), against Docker Hub's pull
  limits. In `/etc`: a node's own mirror replaces it.
- **containerd endpoints:** debug (pprof, no authentication) on a unix
  socket, not `capi-image-builder`'s `0.0.0.0:23541`: the dedicated servers
  have public IPs. Metrics stay on `0.0.0.0:23542` for Prometheus; Cilium
  host policies decide who reaches them.
- **Own `sysroot/`:** node settings differ from `bootc/fedora`: sshd on 22,
  systemd-networkd, no firewalld. One folder per layer ("Layers",
  below).
- **Node settings in the repo** (`rootless` user, its SSH keys, sysctls): a deliberate deviation from
  "credentials from the runtime". `rootless` is `1500:1500` in `sysusers.d`, and
  `tmpfiles.d` refers to it by number: Ignition may create users in the
  initrd, which would take 1000 and collide, and `ostree-populate-var`
  runs before `sysusers` and fails on a name ("Failed to resolve user",
  emergency mode). The sysusers file also declares the group first, or
  systemd-sysusers refuses the fixed GID.
- **SSH keys from the image only:** `AuthorizedKeysFile` is
  `/usr/lib/ssh/authorized_keys/%u`, read-only: a key comes and goes with an
  image. Keys that Ignition, Afterburn or an OpenStack keypair write (to
  `~/.ssh/authorized_keys.d`) are ignored. The test VM adds its key with a
  drop-in of its own (`vm.sh`).
- **No `core` user:** FCOS creates it in the initramfs, from Ignition's
  base config (`00-core.ign`, dracut module `ignition-conf` of
  `fedora-coreos-config`'s `overlay.d`), not from the image's files, and
  `ignition-conf-fcos` enables `afterburn-sshkeys@core`. The Containerfile
  rebuilds the initramfs without both modules, with the base's dracut
  arguments (`usr/lib/dracut/build-parameter.txt`): `rootless` is the only
  login, and CIS's checks of home files had `core`'s, from `/etc/skel`, to
  fail on. Nodes created before keep it.
- **SSH host keys `root:root 0600`**, as Fedora's `sshd-keygen` writes
  them. scap-security-guide's `file_groupownership_sshd_private_key` wants
  group `ssh_keys`, but `file_permissions_sshd_private_key` reads that
  group's GID from `/etc/group` only, and FCOS keeps it in
  `/usr/lib/group`: a `root:ssh_keys` key fails it
  (https://github.com/ComplianceAsCode/content/issues/15320). The first
  is off until upstream accepts `root`
  (https://github.com/ComplianceAsCode/content/pull/15310). Nodes made
  with the former `chgrp ssh_keys` drop-in keep such keys.
- **sshd `00-hardening.conf`:** sshd keeps the first value of a keyword, so
  `00-` beats Fedora's drop-ins. `UsePAM yes` stays: with a locked password
  (`!`), `UsePAM no` would reject every login. The jump-host rule
  (`90-allow-proxyjump.conf`) allows local forwarding only: `-J` needs no
  more. `sshd -T` shows `Match` blocks only with `-C user=…`.
- **Units enabled by links in `/usr/lib/systemd/system`:** FCOS runs
  `systemctl preset-all` on first boot, which removes the `/etc` links of
  `systemctl enable` that no preset names. A preset file would do too, but
  only with the `enable` kept beside it for the first boot of the build
  tests; links in `/usr` are image content, the same on every boot, and
  `preset-all` leaves them alone. Each link is what the unit's `[Install]`
  asks for. `systemctl is-enabled` reports such a unit `disabled` (it only
  looks in `/etc`): check `systemctl show -P WantedBy` instead. The links
  are committed in the unit's `sysroot/<layer>/`, not made by the
  Containerfile: the tree shows what a layer enables, and goss fails on a
  link to a unit no layer ships (`test/system/build.yaml`).
- **Ported from `capi-image-builder`:** chrony sources (Cloudflare + Google,
  `sourcedir /etc/chrony/sources.d` replaces the `pool` line), sysctls
  (`995`-`998`, `90-kubernetes.conf` from image-builder's node
  role; the softnet budget only on machines of 64 CPUs and 128 GB with a
  Mellanox NIC, `sysctl-mlx5-large.service`, whose traffic outruns the
  default budget), modules, `usb-storage` blacklist, resolved fallback DNS
  (`FallbackDNS=`, image-builder `9a267a4`: as `DNS=`, they add to DHCP's in
  `/run/systemd/resolve/resolv.conf`, past kubelet's three nameservers),
  `kube.slice`, `amd-hsmp.service` (AMD CPUs only), coredump settings
  (`systemd-coredump.socket` is static), the QEMU read-ahead udev rule
  (kernel 7.x gives 8 MB read-ahead to rotational QEMU disks, OVH volumes are
  capped at 50 MB/s). Left out: cloud-init default user, AppArmor, IPv6
  forwarding (IPv6 is off in `995-ipv6.conf`). bash completions of kubectl,
  kubeadm and crictl are generated at build: the RPMs ship none.
- **4 MB default socket receive buffer on dedicated servers**
  (`sysctl-metal.service`, `net.core.rmem_default`): the Cilium agent's
  netlink sockets keep the default, which a burst of events on a server with
  hundreds of interfaces overflows (ENOBUFS). VMs have few interfaces and
  keep the kernel default.
- **etcd network tuning on control planes only** (`etcd-network-tuning.path`,
  on kubeadm's etcd manifest): image-builder's udev rule runs it on every
  NIC of every node, where it replaces a worker's multi-queue qdisc with one
  queue for nothing. Each `prio` band gets `fq`, which BBR paces with.
- **etcd defrag on control planes, daily** (`etcd-defrag.timer`,
  `usr/libexec/etcd-defrag`, skipped without kubeadm's etcd manifest):
  etcd only reuses the space of deleted keys; a defrag returns it to the
  disk and keeps the database under its quota. The member blocks
  meanwhile, so each node runs at its own fixed time in a 6-hour window
  (`RandomizedDelaySec`, `FixedRandomDelay`), not `Persistent` (a node
  catching up at boot would defrag while its member resyncs), and skips
  the run while another member is unhealthy (quorum). `endpoint health`
  also fails on any alarm: a NOSPACE one, which the defrag fixes, is
  accepted. Skipped too when it would free less than 100 MB
  (`dbSize - dbSizeInUse`, as `ahrtr/etcd-defrag`'s rules): not worth a
  freeze. A leader first hands leadership to a started voting member
  (`move-leader`, as `etcd-defrag --move-leader`): blocked, it would make
  the followers elect another one. After it, `alarm disarm` clears the
  NOSPACE alarms; it clears every alarm, so not when a CORRUPT one is
  raised. The member's local endpoint only, with kubeadm's healthcheck
  client certificate and the `etcdctl` of its container (etcd
  `etcdctl/ctlv3/command/ep_command.go`). `etcd-defrag.prom` (in
  `/var/lib/etcd-defrag`) gives the last run's result (defragmented,
  skipped_small, skipped_unhealthy, failed) and sizes, for node-exporter.
- **systemd-networkd, not NetworkManager** (as `capi-image-builder`'s
  nodes): NetworkManager stays installed but masked,
  because Ignition, `dracut-network`, `afterburn-dracut` and `kdump-utils`
  require it, and FCOS' prebuilt initramfs runs it to fetch the Ignition
  config. Its extras (`nmstate`, team, tui, cloud-setup) are removed;
  ModemManager isn't installed. Units are enabled by `/usr/lib` links, as the
  rest.
  - VMs get DHCP on their NICs from `99-vm-dhcp.network`
    (`Virtualization=vm`, last match, so Ignition's files win). Dedicated
    servers get their network (bonds) from Ignition only: DHCP on a port
    that isn't the right one gives a wrong default route.
  - `network-online.target` once one link is routable (`--any`): an
    OpenStack NIC without DHCP would hold the boot for 2 minutes.
  - From `capi-image-builder`: `10-nodelocaldns.network` (`KeepConfiguration`:
    the pod owns the address), `20-cni-unmanaged.network` (`lxc*`,
    `cilium_*` and `veth*`: Cilium's pods use netkit, and networkd runs
    out of file descriptors tracking hundreds of them) and
    `10-cni-foreign.conf` (networkd never removes Cilium's routes, rules
    and nexthops).
- **VM or dedicated server, by `systemd-detect-virt`:**
  VM-only: `qemu-guest-agent`, the QEMU read-ahead rule, the OpenStack
  units, `99-vm-dhcp.network`. Bare-metal only: `amd-hsmp.service`,
  `sysctl-metal.service`.
- **Cilium ≥ 1.20 cluster-wide before a node of this image joins:** older
  releases fail on kernel 7.x's BPF verifier (see `vm.sh cluster`).
- **OpenStack disk tags and hostname:** the previous images' udev helper
  read cloud-init's `instance-data.json`. Here `openstack-fetch-metadata` (kernel
  command line `ignition.platform.id=openstack` only) reads
  `/openstack/latest/meta_data.json` into `/run/openstack`, and
  `99-openstack-by-tag.rules` links `/dev/disk/by-tag/<tag>`.
  The config drive is read first, as Afterburn does: a cloud can have no
  metadata service. The file is root-only (user metadata), and udev escapes
  the tag in the link name.
  `openstack-hostname.service` runs `afterburn --cmdline` itself rather than
  requiring `afterburn.service`, which fails on other platforms
  ("unknown provider 'qemu'") and leaves `systemctl --failed` non-empty;
  one shell, because systemd reads an `EnvironmentFile` before
  `ExecStartPre` writes it.
- **Default hostname `node-????-????` in `/etc/hostname`:** a node that
  nothing names gets a unique, stable name instead of `localhost`.
  systemd (FCOS's 259) replaces each `?` with a hex digit of a keyed
  hash of `/etc/machine-id`, which it sets up first: the machine ID
  never reaches the network (systemd
  `src/shared/hostname-setup.c:257-299`, `src/core/main.c:2471-2475`).
  - `hostnamectl hostname` (`openstack-hostname.service`) and Ignition
    replace it; bootc's `/etc` merge then keeps the node's. An Ignition
    file at `/etc/hostname` needs `overwrite: true`, else Ignition fails
    ("A file exists there already and overwrite is false", ignition
    `internal/exec/stages/files/filesystemEntries.go:300`). CABPK writes
    none.
  - It's a static hostname: a DHCP one no longer applies. None is used:
    VMs are named by `openstack-hostname.service`, dedicated servers by
    Ignition.
  - Not `DEFAULT_HOSTNAME=` in `os-release`: systemd uses it only when
    the kernel has no hostname, and the initrd has most likely set
    `localhost` by then (`hostname-setup.c:208-215`); and `os-release`
    is Fedora's.
- **The data array and the public bond's MAC come with bare-metal
  installs** (Later): RAID10, its LUKS bound to the TPM with no PCR, since PCR 4
  changes with each bootc update.

### Layers

- **Three stages, each `FROM` the one before:** `system` (the node's
  packages, `sysroot/system/`), `kube` (Kubernetes' packages,
  `sysroot/kube/`), `image` (`sysroot/vm/`, `sysroot/metal/`, then what
  reads the whole tree). `KUBERNETES_VERSION` is declared in `kube`: a
  Kubernetes release rebuilds `kube` and `image`, and keeps `system`
  cached (checked by building `--target image` with another
  `KUBERNETES_VERSION`: every `system` step `CACHED`). In the source,
  `sysroot/<layer>/` and `test/<layer>/` show what each part of the node
  needs.
- **Smaller downloads, from CI's build cache:** a node downloads only
  the layers whose digest changed. CI keeps the BuildKit cache in the
  Actions cache (`build-bootc.yml`), and passes no `SOURCE_DATE_EPOCH`:
  the Containerfile's `0`, as `build.sh`. A Kubernetes-only change then
  rebuilds `kube` and `image`, and the `system` stage's layers keep
  their digests: the same tars, and podman's gzip gives the same bytes
  from the same tar. Checked on PR #281: two CI runs gave the same 77
  layer digests; a rebuilt `kube` stage changed 3, and a VM's `bootc
  switch` to it fetched "3 (114.1 MB)" where a switch between uncached
  builds fetched "9 (325.9 MB)". The
  price: the `system` packages refresh only on a base or `system`
  change, and on the Sunday and manual runs, which read no cache; the
  nodes' daily grype scan reports what is fixable meanwhile. The image's
  `created` is the build's time. The split costs about 10 MB (1.256 GB
  against 1.247): `kube`'s `dnf install` writes the rpm and dnf
  databases again.
- **A file's layer:** `vm` or `metal` if only that platform uses it,
  else `kube` if only Kubernetes does, else `system`. `vm` and `metal` are
  folders of the `image` stage, not images: one image for VMs and
  dedicated servers (`ConditionVirtualization=`).
- **What reads the whole tree is in `image`:** `52-privileged.rules`
  lists every setuid program, the `kube` packages' included.
  `bootc container lint` runs last. The initramfs stays in `system`: no
  `kube` package adds a dracut module (the tree diff of the split found
  the same initramfs).
- **`goss-bin` is `FROM system`:** a Kubernetes release keeps it cached.

### OpenSCAP

- **scap-security-guide's `cis` profile, tailored**
  (`usr/share/xml/scap/fedora-coreos/tailoring.xml`, each rule's reason
  beside it): CIS Fedora Server level 2, a benchmark auditors know. Level
  2 adds audit rules and a few sshd and kernel settings. Its rules the nodes can't follow are turned off with their reason
  (overlayfs and IP forwarding for Kubernetes, SELinux permissive, no
  passwords), rather than staying at level 1.
  `standard`'s rules that CIS lacks and the image follows (crypto policy,
  auditd retention, root logins) stay selected. Profile `node` for the
  nodes; `build` also turns off what only a booted node shows: rules
  asking systemd, mounts made at boot (`/tmp`, `/dev/shm`), and sysctls
  (each rule also reads the running kernel, in a build the build host's).
- **CIS's easy fixes are in the image:** sshd (`00-hardening.conf`,
  drop-ins 0600, no SHA-1 nor UMAC MAC), idle shells exit after 15 min
  (`etc/profile.d/tmout.sh`), sudo `use_pty`, umask 027, login banners in
  `/etc/issue{,.net}`, journald, `atm` and `can` modules off, kernel and
  IPv4 sysctls (`usr/lib/sysctl.d/990-cis.conf`), no `dnsmasq`, `rsync`
  nor `rpcbind` (`rpm -e` fails if a package requires them; `rpcbind`'s
  dependants are NFSv3's, NFSv4 needs none of them). umask has
  no drop-in: `login.defs` and `/etc/bashrc` are edited in place.
  `/etc/systemd/journald.conf` replaces the base's empty one, not a
  drop-in, as the `ForwardToSyslog` check reads only it.
- **`kernel.yama.ptrace_scope = 1`:** a debugger in a pod needs
  `CAP_SYS_PTRACE` (`kubectl debug --profile=general`). The base's
  `10-default-yama-scope.conf` (0) is deleted, not masked from `/etc`: its
  package is required by `elfutils-libs`, and the rule reads every
  `sysctl.d` file.
- **CIS's crypto policy modules turned off, their sshd part done in
  `00-hardening.conf`:** `update-crypto-policies` is Python, which the
  image lacks, and the modules' other effects reach only programs using
  OpenSSL or GnuTLS: kubelet, containerd and bootc are Go. sshd offers
  no CBC cipher already; its `MACs` line keeps the policy's but SHA-1
  and UMAC, and a policy change no longer reaches sshd's MACs.
- **No `systemd-journal-remote`:** the cluster's log collector, a pod
  reading the journal, ships the logs off the node.
- **Content in the image, Fedora's data stream alone** (21 MB of 735):
  the nodes scan with the build's content and tailoring. rpm's
  `%_netsharedpath` (`lib/transaction.cc` of `github.com/rpm-software-management/rpm`,
  exact paths) skips the other products and the remediation scripts, and
  `rpm -V` doesn't report them missing.
- **Scan in stages after the image** (`scan`, then `reports` from
  `scratch`): the reports stay out of the image, and the image stays the
  default target. `build.sh` and CI export them.
- **Built with BuildKit, in CI too** (`builder: buildkit` in
  `build-bootc.yml`, then `podman load` for the signing): podman and
  buildah mount `/run/.containerenv` in every `RUN`, and SSG's
  `installed_env_is_a_container` check turns the rules of a machine off
  when it exists. `OSCAP_PROBE_ROOT` on a mount of the image gave
  unstable results, and `chroot` lacks `/proc`.
- **`build.sh` and CI fail on a failed rule**, before building the image:
  `oscap` exits 2 when a rule fails, which the `scan` stage accepts so
  that the report is exported; any other error fails the stage.
- **Nodes scan daily** (`openscap.timer`, `usr/libexec/openscap-scan`):
  profile `node`, results and metrics for node-exporter's textfile collector
  in `/var/lib/openscap`. A systemd timer, not a Kubernetes job: the
  image's own scanner, content and tailoring, nothing to keep in step. No
  HTML report: nobody opens one on a node, the metrics name the rules.
  `MemoryHigh=` above oscap's peak (about 320 MB): past it, the kernel
  reclaims the scan's memory rather than the pods'.
- **The scan doesn't see `/sysroot`, containerd's storage nor the pods'
  volumes** (`InaccessiblePaths=` of `openscap.service`): the file rules
  (world-writable, unowned) walk every local mount, `/sysroot` included,
  which shows `/var` again and the ostree repo. On a node they failed on
  the containers' files only: image owners unknown to the host, kubelet's
  0666 `termination-log`, `emptyDir` folders. Hidden behind an empty tmpfs,
  they are skipped and the rules keep checking the host's own files; the
  scan also gets faster.
- **One series per selected rule** (`openscap_rule`, about 280 per node),
  with its title, severity, CIS section and result: an alert names the
  failed rule.
- **The kernel's audit state, with the scan** (`audit_*` of
  `openscap.prom`, from `auditctl -s` and `-l`): the scan reads the rules'
  files only. `audit_lost_events` counts the events dropped since boot;
  `audit_rules_rejected`, the rules of `/etc/audit/audit.rules` the kernel
  refused, which `-c` loads past and `-e 2` keeps out until a reboot.
- **Nushell** (Fedora's package) writes the metrics: XCCDF is XML, which
  bash and jq can't read. Fedora's release is 0.99, older than the current
  one: the scripts use no later syntax. `usr/share/nushell/prometheus.nu`
  holds the text format, for both scripts.
- **`/etc` drift, hourly** (`etc-diff.timer`, `usr/libexec/etc-diff`,
  `ostree admin config-diff`): `/usr` is the image's and read-only, `/etc`
  is what changes on a node. It stands in for AIDE (`aide_build_database`
  off). Apart from the scan: it takes a second, so it runs more often, and
  a failed scan doesn't stop it.
- **A series per path of `/etc` changed**, with its metadata and
  modification time: drift is tied to a file and a moment. Label
  `expected`: whether the node writes the path on purpose (first boot,
  Ignition, Cluster API's bootstrap, kubeadm, Cilium, Cinder CSI), from a
  list in the script. Most of a node's changed paths are such, so only
  `expected="false"` is worth an alert; a path the node now writes on
  purpose joins the list. The list names files, not folders, where one
  more file would run: a new static pod or systemd unit is unexpected. A
  directory has no size nor modification time: they follow its entries.
- **`oscap xccdf eval`, not upstream's `oscap-im`:** `oscap-im` remediates
  the image during the build; here every fix is a Containerfile line.
  scap-security-guide spots a bootc image being built by `/ostree` being a
  symlink, but OpenSCAP's file probe follows symlinks: the build would be
  scanned as a plain system (`oscap-im` uses the SCE engine instead). The
  `scan` stage creates `/run/ostree-booted`, the other sign, which a node
  has: `audit_rules_privileged_commands` would otherwise count the setuid
  files of `/sysroot/ostree/repo`. Fixed upstream by
  https://github.com/ComplianceAsCode/content/pull/15303.
- **Upstream fixes:** when a scap-security-guide release carries
  https://github.com/ComplianceAsCode/content/pull/15304 (Fedora keys,
  rpm 6), `ensure_fedora_gpgkey_installed` goes back on; with
  https://github.com/ComplianceAsCode/content/pull/15310,
  `file_groupownership_sshd_private_key` goes back on. `display_login_attempts`
  (`standard`, not CIS) can't pass on Fedora 43 and later:
  https://github.com/ComplianceAsCode/content/issues/15305.
- **authselect profile `local`, the base's, not `sssd`:** SSSD 2.11
  removed the files provider, so it has nothing for local users; the
  `sssd` daemon package isn't installed, and `sssd.service`'s conditions
  skip it with no `/etc/sssd` config. `without-nullok`: no login with an
  empty password.
- **`/etc/securetty`, one empty line:** no PAM module of Fedora reads it;
  `no_direct_root_logins` wants it.
- **Audit syslog plugin** (`audispd-plugins`, `active = yes`): audit events
  reach the journal. Its `/var/spool/audit` is removed, as `/var` ships
  empty.
- **Audit rules of CIS 6.3.3** (`etc/audit/rules.d/`), written from
  scap-security-guide's remediations, its field order kept so its checks
  read them. Fedora's `audit.rules` goes: its `-a task,never` turns syscall
  auditing off. The rules record sessions only, which have a login uid:
  most with `auid>=1000`; the clock, kernel modules, programs run as
  another user and the watches, any session. `-a task,never -F
  auid=unset` leaves out services, kubelet, containerd and the pods,
  so CIS' rules that name no user miss their events too (chronyd's clock
  adjustments, a daemon's write to `/etc/hosts`): with a rule loaded,
  the kernel tracks every syscall of each process it audits, measured at
  about +60 ns a call and +200 ns one with a path (aarch64, kernel 7.0;
  the number of rules hardly matters). Tetragon and Falco watch the
  pods. x86_64-only
  syscalls are in a file of their own, deleted on other architectures.
  `52-privileged.rules` is written in the build from the image's setuid
  and setgid programs, all in `/usr`: the check wants exactly those.
  `-e 2` last: rules change only with a reboot, so a new image.
- **`audit=1 audit_backlog_limit=8192`** (`kargs.d/20-audit.toml`): the
  kernel audits from boot, and holds events until auditd starts.
  `grub2_audit_argument` and `grub2_audit_backlog_limit_argument` are
  off: besides the boot entries, they want the argument in
  `/etc/default/grub`, which bootc doesn't read; an unread copy there
  would only satisfy the check. The scan's `audit_enabled` and
  `audit_backlog_limit` metrics report the kernel's values.
- **auditd suspends and rotates** (tailoring's values): a full disk or a
  write error stops logging instead of halting the node or dropping it to
  single-user mode, and logs rotate instead of filling `/var`. CIS level
  2 wants the opposite; a node going down with its disk is worse here,
  and the events also reach the journal.
- **sshd: no GSSAPI, forwarding for rootless only.** Fedora's
  `50-redhat.conf` line `GSSAPIAuthentication yes` is deleted: the check
  fails on any line saying `yes`, though `00-hardening.conf`'s comes
  first. `sshd_disable_forwarding` is off: `ssh -J` through a node needs
  rootless's `DisableForwarding no`.
- **SquashFS blocked** (`modprobe.d/hardening.conf`): the node's
  filesystems are XFS and ext4, composefs is EROFS. overlayfs stays:
  containerd's snapshotter.

### Vulnerabilities (grype)

- **grype, not `oscap oval eval`:** Fedora publishes no OVAL vulnerability
  feed (Red Hat's covers RHEL), and OVAL only sees rpm packages, not the
  Go modules built into kubelet or containerd. grype's database
  holds Fedora's security updates since 2026-02 (vunnel's `fedora`
  provider, from Bodhi), and grype reads Go binaries' build info. Trivy
  detects CoreOS but reports nothing for it.
- **Fedora's package, not anchore's release:** signed by Fedora, updated
  with the image's other packages, nothing to pin. It lags a few releases
  behind; the database schema is the same, and it reads Fedora's data.
- **`/usr` and `/etc` only:** what the image ships. `/var` holds pod
  images and data, `/sysroot` a second copy of `/usr`.
- **`--by-cve`:** one id per vulnerability on every node, whichever
  database matched it (GHSA, GO-…).
- **`grype.prom`, the fixable ones of Medium severity and above**, one
  series per vulnerability, package and path, valued by grype's risk
  score; EPSS and CVSS by id; counts of every match by severity and fix
  state, and of the ignored ones by id, so an ignore rule stays visible;
  the database's age. `grype.json` keeps every match.
- **`build.sh` and CI fail on a fixable Critical**: the stage reports,
  and the build stops after exporting, as for OpenSCAP.
- **Ignore rules for what the image can't fix**
  (`usr/share/grype/ignore.yaml`): Kubernetes' and Fedora's builds, and
  false positives. In the image, so the nodes ignore the same. Each names
  the package's exact version: an update ends the rule. grype applies them
  after `--by-cve` too, so a CVE id matches.
- **A daily timer, as OpenSCAP's:** the database changes daily, the image
  doesn't. Each node downloads the database when a newer one exists.
- **No `etcd` package:** Fedora's is 3.5.13, built with Go 1.22.2 (five
  fixable Criticals), and kubeadm's server is 3.6. `etcdctl` is the one in
  kubeadm's etcd image (`crictl exec`), at the server's version.

### Disk images, build and test

- **Disk images with `custom-coreos-disk-images`, pinned to a commit
  (`disk-images.sh`, `disk_images_commit`):** greenboot boot counting needs
  the bootupd static GRUB configs that only this installer writes. It sets
  `mitigations=auto,nosmt` by default; `disk-images.sh` passes
  `--extra-kargs mitigations=auto`, because `nosmt` turns off half the CPUs
  of a node. It installs from `ostree-image-signed:`, so the disk's
  origin checks CI's signature from the first boot.
- **qcow2 compressed after osbuild** (`qemu-img convert -c`): the
  OpenStack pipeline writes it uncompressed, and a GitHub release asset
  must be under 2 GiB.
- **OpenStack qcow2 as a GitHub release, from CI** (`disk-image` job of
  `build-bootc.yml`, on `main`): one release per change of this folder,
  any file, docs and tests included (simplest rule), Renovate's version
  bumps included: `fedora-coreos-<BASE_VERSION>-v<KUBERNETES_VERSION>-<short
  sha>`. The change is found by comparing with the newest release's tag,
  so a run cancelled by a newer push loses none; the weekly rebuild makes
  no release. The newest 3 releases stay, older ones are deleted with
  their tags: a node needs the disk only to be created, then follows the
  image tag. Made from the image just pushed, by digest (the tag may move
  meanwhile; the disk's origin stays the tag), checked with the image's
  `policy.json`, in a privileged container of the image's Fedora release
  (osbuild needs root and loop devices). With a `.sha256` file and a build
  provenance attestation (`gh attestation verify`), as the image has. gh
  publishes a release only once its assets are uploaded (cli/cli
  `pkg/cmd/release/create/create.go`, `draftWhileUploading`), and only
  published releases count as the newest one: a failed upload makes no
  release without a disk.
- **Container image on a cluster's BuildKit** (`BUILD_KUBE_CONTEXT`,
  `kubectl port-forward` to a free local port, a `docker buildx` remote
  builder, `--output type=oci`): the workstation is arm64 and the targets
  are x86_64.
- **Disk images in a privileged container, the workbench**
  (`workbench.sh`): the BuildKit is rootless and can't run osbuild; the
  tool names its output after the host architecture, so it runs on
  x86_64. Two backends, one interface (`up`, `down`, `exec`) and one
  package list: `kube`, a pod on the build cluster (`workbench.yaml`,
  git-ignored: it names the cluster; its namespace must allow privileged
  pods, `activeDeadlineSeconds` bounds its life), and `podman`, a
  rootful container on an x86_64 host with KVM (CI's `vm-test` job;
  `--init` reaps the daemonized qemu and swtpm, as the pod's
  `shareProcessNamespace`).
- **Test VM: `qemu-system-x86_64` with KVM in the workbench:** the
  cluster's bare-metal node and GitHub's runners expose `/dev/kvm`. Ignition goes through `fw_cfg`, a throwaway SSH key
  comes from Butane. Its disk is NVMe, as a dedicated server's.
- **Workbench on the image's Fedora release** (`workbench.sh` reads the
  major of `BASE_VERSION`): osbuild builds the disk
  images from a tree of the same release, and the pin can't drift.
- **Cilium ≥ 1.20 in `vm.sh cluster`:** 1.18.3 fails on kernel 7.2's BPF
  verifier (`call bpf_set_retval#187: R1 is not a scalar`). It runs with the
  legacy iptables modules blocked.
- **amd64 first:** the targets are x86_64. CI builds arm64 too, but
  scans and makes disk images of amd64 only.
- **Signed by CI as the other images** (`build-bootc.yml`):
  `policy.json` asks its signature for `ghcr.io/spnngl/images`
  (`bootc/REFERENCES.md`), and the build checks it with `policy.jq`.
  Without the `registries.d` file, podman and bootc don't look up the
  signatures, and the policy refuses every update. CI's `push` and
  `disk-image` jobs install this folder's key and `registries.d` file
  (matrix key `signing`): the check uses the files the nodes ship.
- **Own build context, this folder:** if the build succeeds, it read no
  file of another image. The signature files and `policy.jq` are copies
  of `bootc/fedora/`'s, in this folder: a change to them makes a
  fedora-coreos release ("OpenStack qcow2 as a GitHub release"). A key
  rotation updates both copies; the `push` job checks the signature with
  this folder's key, so a stale copy fails there.
  `.dockerignore`, not `.containerignore`: BuildKit reads only the
  former, buildah both.
- **goss checks the image's files at build** (`test/<layer>/build.yaml`, stage
  `goss`, report `goss/build.tap` of `reports`): what holds without
  booting (packages, files, unit links and drop-ins, `sshd -T`, the
  merged containerd config). CI runs it on every build, through
  `--target reports`; `check-reports.sh` fails on a `not ok`, or on a
  report with no check (goss couldn't read the suite). `test.sh` runs
  what needs the booted node.
- **goss from Fedora's package** (`goss-bin` stage, `dnf install`): no
  pin to update, it follows `BASE_VERSION` like cri-tools ("Versions not
  pinned"), and the image's glibc runs it (it is dynamically linked). The
  `goss` stage mounts its binary alone, so the checks see the shipped
  tree, rpmdb included, and grype never scans goss. `--network=none`: the
  checks read the image only.
- **A Containerfile `grep` only guards the `sed` above it** (it fails
  when the edit matched nothing); the checks of a result are in
  `test/<layer>/build.yaml`, one place per fact.
- **Unit facts as files at build:** a unit enabled by a link is checked
  as that link (`systemctl is-enabled` calls it `disabled`), a masked one
  as its `/etc` link to `/dev/null`, a condition or slice as its line in
  the unit or drop-in. `systemctl show` needs a running systemd.
- **VM tests in CI, and by hand** (`build-bootc.yml`, job `vm-test`):
  the job boots the build job's image, on pull requests too, and runs
  every suite of the Build check (`AGENTS.md`), `test-greenboot.sh`
  included. A public repository's `ubuntu-26.04` runner has 4 vCPUs,
  16 GB and `/dev/kvm`: room for the VM (4 CPUs, 8 GB). The `push` job
  pushes fedora-coreos only if it passed: nodes follow the tag with
  `bootc upgrade`, and greenboot rolls back only on its required
  checks. By hand, the same scripts run in the cluster's workbench.
- **VM tests as goss suites** (`test.sh node|wx|cluster`), like the
  build's: `test/<suite>.yaml` includes every layer's `<suite>.yaml`
  (`system/`, `vm/`, `metal/`, `kube/`), so a check lives in the layer
  that ships what it checks. goss is the workbench's (Fedora's package,
  same release as the image), copied into the VM with the suite: the
  image ships no test tool. One check at a time (`--max-concurrent 1`):
  some change state (links, test keys), then restore it. A state goss's
  resources can't read (`masked`, a condition skip, a live `sshd`) is a
  `command`. `cluster` retries the whole suite for 4 minutes
  (`--retry-timeout`): after a boot, the API then Cilium come up after
  sshd, the node still shows `Ready` from before the boot, and goss runs
  checks in no set order, so a first check can't wait for the others.
- **`/var` holds the base's entries only** (`test/system/build.yaml`):
  bootc unpacks the image's `/var` at the first deployment only, so what
  a layer leaves there never reaches an upgraded node; `tmpfiles.d`
  makes it.
- **The test VM's sshd drop-in is `0600`** (`vm.sh`):
  OpenSCAP's `file_permissions_sshd_drop_in_config` fails on `0644`, and
  `test.sh node` fails on any failed rule.
- **Renovate** (`renovate.json5`): `BASE_VERSION` through
  the dockerfile manager; `KUBERNETES_VERSION` (GitHub releases of
  `kubernetes/kubernetes`, one PR per patch and per minor release: kubeadm
  upgrades one minor at a time), Cilium (its Helm
  repository) and `disk_images_commit` (weekly, no release upstream)
  through custom managers.
- **Automerged once every check is green**, the build, scans and
  `vm-test` of `build-bootc.yml` included: a Fedora CoreOS release of the
  same major and a Kubernetes patch release (the tag stays, nodes take
  them with `bootc upgrade`, and greenboot rolls back a node that fails to
  come up), Cilium's minor and patch releases and `disk_images_commit`
  (only `vm-test` runs them: `vm.sh cluster`, the qemu disk image it
  boots). Renovate merges them itself (`platformAutomerge: false`):
  GitHub's auto-merge waits for the required checks only, and
  `build-bootc.yml` has none.
- **By hand:** a new major of the base, a Kubernetes minor (both new
  tags: hosts move with `bootc switch` or new machines) and a Cilium
  major.

### Bootstrap

- **CABPK `format: ignition`, then a webhook**
  (`spnngl/ignition-converter`): FCOS Ignition reads spec 3.x only;
  CABPK renders 2.3 for Flatcar. The webhook
  mutates the bootstrap Secret (`cluster.x-k8s.io/secret`, `format:
  ignition`). Files off the `root` filesystem are denied: the translator
  would map an undeclared filesystem to `/`. Declared ones (`diskSetup`)
  convert with no spec 3 `path`, rather than one parsed from CABPK's mount
  units: with no file on them Ignition needs none, and those units mount
  them at boot.
- **OS updates:** VMs get a new machine through Cluster API. Bare metal is
  updated in place by bootc-operator with greenboot-rs rolling back
  (Later), because reinstalling a dedicated server
  is slow.
- **Bare-metal install through OVH rescue and `coreos-installer
  --ignition-file`** (Later): BYOLinux lays the disks out as one ext4 RAID1
  `/` and boots it with the image's own script; FCOS needs its own EFI,
  `boot` and `root` partitions and Ignition at first boot.

### Greenboot

- **`greenboot-default-health-checks` kept**, though its checks do little
  here: the watchdog one skips until `GREENBOOT_WATCHDOG_CHECK_ENABLED=true`
  (`/etc/greenboot/greenboot.conf`), the DNS one skips as
  `/etc/ostree/remotes.d` is empty, and the wanted check of the update
  servers fails on that, a warning only. It orders greenboot after the
  network.
- **Our checks** (`usr/lib/greenboot/check/required.d/`): containerd
  active; kubelet healthy (`127.0.0.1:10248/healthz`), skipped until
  `/etc/kubernetes/kubelet.conf` exists, because a node that kubeadm hasn't
  joined has no running kubelet. Ordered after containerd and kubelet
  (`greenboot-healthcheck.service.d/10-ordering.conf`).
- **`GREENBOOT_MAX_BOOT_ATTEMPTS` is greenboot's default (3):** tested by
  `test-greenboot.sh`: three failed boots, then rollback. greenboot
  remounts `/boot` read-write for the operation and restores it, which
  W^X doesn't prevent.

### W^X

Every writable mount is `noexec,nosuid,nodev`: `/var`, `/etc`, `/sysroot`,
`/sysroot/ostree/deploy/*/var`, `/boot`, `/boot/efi`, `/tmp`, `/dev/shm`,
`/run` (`usr/libexec/wx-remount`; what isn't a mount point is skipped,
`/boot/efi` isn't one on FCOS). Units run scripts from `/usr` or through an
interpreter: `noexec` doesn't stop `bash <file>`, it is defense in depth.

- **`bind` in the remount:** a plain remount of `/sysroot` (read-only xfs)
  fails with "mount point is busy". A bind remount clears the per-mount
  flags it isn't given, so `ro` is passed again where it was set: `/sysroot`
  and `/boot` stay read-only (FCOS warns otherwise).
- **`/sysroot/ostree/deploy/*/var`:** a bind mount of `/var` with its own
  flags, so `/var`'s files could be executed through it.
- **`After=local-fs.target`, `Before=sysinit.target`** (not before
  `local-fs.target`): `/boot` is mounted by then, and everything the unit
  remounts exists.
- **Exception `/var/lib/kubelet` (`var-lib-kubelet.mount`, `bind,exec`):**
  pod volumes (`emptyDir`, `configMap`, `secret`) hold files workloads
  execute.
- **Exception `/var/opt/cni/bin` (`var-opt-cni-bin.mount`, `bind,exec`):**
  Cilium installs `cilium-cni` there and containerd runs it.
- **No exception for `/var/lib/containerd`:** the cluster pod test passes
  without it (container root filesystems are overlay mounts of their own).
- **The tests' goss runs from a tmpfs of its own** (`/run/goss`, exec,
  mounted and unmounted by `test.sh`): `noexec` refuses `execve` and the
  exec `mmap` of its libraries' loader. A temporary mount leaves no
  exception on the node.

### GPU image

`fedora-coreos-nvidia`: this image plus NVIDIA's open kernel modules,
the driver's compute userspace and the Container Toolkit, for the OVH
Scale-GPU-3 dedicated servers (NVIDIA L4). The GPU Operator runs on it
with `driver.enabled=false` and `toolkit.enabled=false`; CUDA comes with
the workloads' images, never on the host.

- **Driver and toolkit pinned in the Containerfile, Renovate proposes
  them, a person merges** (`ARG NVIDIA_VERSION`,
  `ARG NVIDIA_CONTAINER_TOOLKIT_VERSION`): CI builds the modules but
  runs no GPU, so only a node of the GPU image tells a driver that
  loads from one that doesn't. Renovate reads each RPM repository's
  `repodata/` through its `rpm` datasource (`registryUrl` is the
  folder holding `repomd.xml`, `lib/modules/datasource/rpm/repomd.ts`),
  which returns `<version>-<release>` (`620.70.06-1.fc44`): `extractVersion`
  drops the release, as the Containerfile pins the version, and
  every package of the driver is installed at it (NVIDIA's RPMs
  require each other at one version, epoch 3).
- **Driver branch R620 only** (`allowedVersions: "/^620\\./"`): NVIDIA's
  Long Term Support Branch, supported until September 2029
  (<https://docs.nvidia.com/datacenter/tesla/drivers/supported-drivers-and-cuda-toolkit-versions.html>).
  NVIDIA's `fedora44` repository only holds branches released during Fedora 44's life
  (610 to 620; the fleet's R580 is in `fedora42` and `rhel10`); a new
  branch changes the kernel module and the CUDA the workloads run
  against: a person moves to it.

- **A stage of its own, `nvidia`, between `kube` and `image`; the
  build arg `IMAGE_BASE` picks what `image` builds on** (`kube` by
  default): `fedora-coreos` never builds `nvidia`, the GPU image's
  build (`IMAGE_BASE=nvidia`) runs the same `image`, scan and goss
  stages on top of it. One Containerfile, so a change to the node
  reaches both images in the same commit; a second Containerfile
  would copy its stages.
- **No `lockdown=integrity`:** the modules are unsigned and
  lockdown refuses them. `nvidia` deletes `kargs.d/10-lockdown.toml`
  (its own file for this), and bootc removes the argument from a node
  that switches to the image. The modules load because
  `CONFIG_MODULE_SIG_FORCE` is unset and Secure Boot is off on the GPU
  nodes; Fedora's kernel locks down again under Secure Boot
  (`CONFIG_LOCK_DOWN_IN_EFI_SECURE_BOOT=y`), and the modules stop
  loading: enabling Secure Boot on a GPU node needs a signing key
  and its enrollment first.
- **No `kernel.modules_disabled=1` to make up for it:** it forbids every
  module load until reboot, and a Kubernetes node loads modules on
  demand all its life, through `request_module` (`/sbin/modprobe`):
  Cilium creates `veth`, `vxlan`/`geneve`, `clsact` and WireGuard
  devices as pods and features come (`pkg/datapath/loader/netlink.go`,
  `pkg/wireguard/agent/agent.go`) and counts on the kernel loading
  `dummy` for it (`pkg/datapath/linux/probes/managed_neighbors.go`);
  containerd needs `overlay` and the pods' volumes their filesystem's
  module; the GPU stack loads `nvidia-uvm` lazily. No moment exists
  after which the set is complete: a missed module fails a pod or the
  network at runtime, and only a reboot fixes it.
- **The GPU build's VM tests are the fedora-coreos ones:** they cover
  the Containerfile and `sysroot/` up to `nvidia`, not the GPU image's
  bytes (its leg runs `dnf` on its own, in the same run); no VM test
  has a GPU.
