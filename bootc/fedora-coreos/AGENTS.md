# fedora-coreos

Fedora CoreOS bootc image for kubeadm nodes of Cluster API clusters
(OpenStack VMs, OVHcloud dedicated servers), from
`quay.io/fedora/fedora-coreos:<BASE_VERSION>`. Sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **One image, not the three of `bootc/AGENTS.md`**: kubeadm nodes
  only, no k3s, no Docker. Its stages are its layers, each `FROM` the one
  before: `system`, `kube` (Kubernetes' packages and files, so that a
  Kubernetes release rebuilds it alone), `image` (the `vm` and `metal`
  files, then what reads the whole tree). The stages after `image` scan
  it (OpenSCAP, grype) and check its files (goss, `test/build.yaml`);
  `image` is the default target. Tag `<major>-v<minor>` of `BASE_VERSION` and
  `KUBERNETES_VERSION`, the Containerfile's `ARG`s, written by
  `versions.sh` for `build.sh` and CI: a patch release keeps the tag.
- **A second image, `fedora-coreos-nvidia`, for the GPU nodes:** the same
  Containerfile with `--build-arg IMAGE_BASE=nvidia`, which puts the
  `nvidia` stage (NVIDIA's driver and toolkit, `sysroot/nvidia/`) under
  `image`. Same tag, amd64 only, built and pushed by CI
  (`REFERENCES.md`, "GPU image"). `fedora-coreos` never builds that stage.
- **Own build context, this folder** (`.dockerignore`), and own
  `sysroot/` (no firewalld, sshd on 22, systemd-networkd), one folder
  per layer: `sysroot/<layer>/` holds the layer's files at their path in
  the image. A file goes in `vm` or `metal` if only that platform uses
  it, else in `kube` if only Kubernetes does, else in `system`. A path
  like `usr/libexec/etc-diff` below is in one of them. The signature
  files (public key, `registries.d`) and `policy.jq` are copies of
  `bootc/fedora/`'s: a key rotation updates both. Files that Ignition or the user
  may own stay in `/etc`; the rest is in `/usr`. SSH keys are only in
  `/usr/lib/ssh/authorized_keys/`: sshd reads no other file.
- **No host firewall, no iptables rules:** Cilium filters; the legacy
  iptables modules can't load.
- **systemd-networkd, not NetworkManager** (masked, kept for the initrd).
- **One image for VMs and dedicated servers**, told apart by
  `systemd-detect-virt`: a VM-only unit or file has
  `ConditionVirtualization=vm` (or `Virtualization=vm`), a bare-metal-only
  one `ConditionVirtualization=false`; a bare-metal script refuses to run
  in a VM.
- **W^X**: every writable mount is `noexec` (`wx-remount.service`). A
  new exception is a `bind,exec` mount unit with its reason in a comment
  and in REFERENCES.md; anything under `/etc` or `/var` runs through an
  interpreter (`bash <file>`).
- **Units are enabled by links in `/usr/lib/systemd/system`**, committed
  as symlinks (`../<unit>`) in the unit's layer, never by `systemctl
  enable` or a preset: FCOS runs `systemctl preset-all` at first boot,
  which drops the `/etc` links no preset names.
- **CI** (`.github/workflows/build-bootc.yml`) builds it with BuildKit,
  as `build.sh` (podman's `/run/.containerenv` turns OpenSCAP's machine
  rules off), for amd64 and arm64; scans amd64; on `main`, pushes and
  signs `ghcr.io/spnngl/images/fedora-coreos:<major>-v<minor>` and
  releases the OpenStack qcow2 (`disk-images.sh`) when a file of this
  folder changed, keeping the newest 3 releases. The GPU image's qcow2 is
  an asset of the same release.
- **OpenSCAP** checks the image at build and the nodes against
  scap-security-guide's `cis` profile (CIS level 2), tailored in
  `sysroot/system/usr/share/xml/scap/fedora-coreos/tailoring.xml`: a rule the
  image doesn't follow is turned off there, with its reason beside it.
  `check-reports.sh` fails `build.sh` and CI on a failed rule, after
  exporting the report. The
  nodes scan daily (`openscap.timer`, results in `/var/lib/openscap`), and
  list `/etc`'s drift hourly (`etc-diff.timer`, `/var/lib/etc-diff`); the
  paths the node writes on purpose are in `usr/libexec/etc-diff`.
- **grype** lists the CVEs of `/usr` and `/etc`, at build and daily on
  the nodes (`grype.timer`, `/var/lib/grype`), with `usr/libexec/grype-scan`.
  `grype.prom` holds the fixable ones of Medium severity and above;
  `check-reports.sh` fails on a fixable Critical. One
  the image can't fix is ignored in `sysroot/system/usr/share/grype/ignore.yaml`,
  at the package's exact version, with its reason.
- **Checks:** in the layer that ships what they check: what holds for
  the image's files in `test/<layer>/build.yaml` (goss, at every build,
  CI included), what needs the booted node in
  `test/<layer>/<suite>.yaml` (goss, `test.sh`). A Containerfile `grep` only guards the
  `sed` before it.
- **Renovate** proposes `BASE_VERSION`, `KUBERNETES_VERSION`, the Cilium
  of `vm.sh` and `disk-images.sh`'s `disk_images_commit` (`renovate.json5`),
  automerged once every check is green (`vm-test` runs the build check)
  but for a new `BASE_VERSION` major, a Kubernetes minor (both new tags)
  or a Cilium major: review those by hand. The GPU image's
  `NVIDIA_VERSION` and `NVIDIA_CONTAINER_TOOLKIT_VERSION` (`REFERENCES.md`,
  "GPU image") are never automerged: only a GPU node runs them.

## Layout

- `Containerfile`, `sysroot/<layer>/`: the image (`system`, `kube`,
  `vm`, `metal`).
- `build.sh`: container image and its scan reports
  (`output/fedora-coreos/reports/`) on the cluster's BuildKit, then disk
  images (`qemu`, `openstack`, `metal`) in the workbench
  (`workbench.sh`: a pod of the build cluster, from the local, git-ignored
  `workbench.yaml`, or with `WORKBENCH=podman` a container on an x86_64
  host with KVM, as CI's `vm-test` job).
- `versions.sh`, `check-reports.sh`, `disk-images.sh`: the tag, the scan
  gate and the disk images, shared by `build.sh` and CI.
- `test/build.yaml`, `test/<layer>/build.yaml`: the goss checks of the
  build.
- `vm.sh`, `test.sh`, `test/<suite>.yaml`, `test/<layer>/<suite>.yaml`,
  `test-greenboot.sh`: a test VM in the workbench (an NVMe disk), and the
  goss suites run on it (`node`, `wx`, `cluster`), split by layer.
  `test/nvidia.yaml` is the GPU image's suite, run on a node with a GPU
  (`test.sh nvidia <user>@<host>`), never on the test VM.

## Build check

`BUILD_KUBE_CONTEXT` is the kube context of the build cluster, which runs the BuildKit and the workbench.
CI's `vm-test` job runs the same commands from `vm.sh up` on, on the
build job's image.

```sh
export BUILD_KUBE_CONTEXT=<context>
bootc/fedora-coreos/build.sh qemu,openstack,metal
bootc/fedora-coreos/vm.sh up
bootc/fedora-coreos/test.sh node      # kernel, users, live sshd, units' state, sysctls, OpenSCAP, grype
bootc/fedora-coreos/vm.sh cluster     # kubeadm init + Cilium
bootc/fedora-coreos/test.sh cluster   # node Ready, pod runs scripts from emptyDir and configMap
bootc/fedora-coreos/test.sh wx        # noexec everywhere but the exceptions
bootc/fedora-coreos/vm.sh reboot
bootc/fedora-coreos/test.sh wx        # again, after a boot with a cluster
bootc/fedora-coreos/test.sh cluster   # the cluster comes back
bootc/fedora-coreos/test-greenboot.sh # good update kept, bad one rolled back
bootc/fedora-coreos/vm.sh down
bootc/fedora-coreos/workbench.sh down
```

Done when each command exits 0. Run `test.sh wx` again after a reboot.

The GPU image (`IMAGE_BASE=nvidia`) has one more check, on a node with a
GPU that runs it (`REFERENCES.md`, "GPU image"):

```sh
bootc/fedora-coreos/test.sh nvidia <user>@<host>
```
