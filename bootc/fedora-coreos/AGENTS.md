# fedora-coreos

Fedora CoreOS bootc image for kubeadm nodes of Cluster API clusters
(OpenStack VMs, OVHcloud dedicated servers), from
`quay.io/fedora/fedora-coreos:<BASE_VERSION>`. Sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **One image, not the two of `bootc/AGENTS.md`**: kubeadm nodes
  only, no k3s, no Docker. Its stages are its layers, each `FROM` the one
  before: `system`, `kube` (Kubernetes' packages and files, so that a
  Kubernetes release rebuilds it alone), `image` (the `vm` and `metal`
  files, then what reads the whole tree). The stages after `image` scan
  it (OpenSCAP, grype) and check its files (goss, `test/build.yaml`);
  `image` is the default stage. Tag `<major>-v<minor>` of `BASE_VERSION` and
  `KUBERNETES_VERSION`, the `docker-bake.hcl`'s `BASE` and `KUBERNETES`
  variables, which set the Containerfile's `ARG`s: a patch release keeps
  the tag.
- **A second image, `fedora-coreos-nvidia`, for the GPU nodes:** the same
  Containerfile with the build arg `IMAGE_BASE=nvidia`, which puts the
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
- **CI** (`.github/workflows/build-bootc.yml`) builds it with BuildKit
  (podman's `/run/.containerenv` would turn OpenSCAP's machine rules
  off), for amd64 and arm64, when a file of this folder or its
  `docker-bake.hcl` changed; the `check` stage scans amd64; on `main`,
  pushes and signs `ghcr.io/spnngl/images/fedora-coreos:<major>-v<minor>`
  once the VM tests of its line passed, and releases the OpenStack qcow2
  (`disk-images.sh`), keeping the newest 3 releases of each line. The GPU
  image's qcow2 is an asset of the same release.
- **OpenSCAP** checks the image at build and the nodes against
  scap-security-guide's `cis` profile (CIS level 2), tailored in
  `sysroot/system/usr/share/xml/scap/fedora-coreos/tailoring.xml`: a rule the
  image doesn't follow is turned off there, with its reason beside it.
  The `check` stage fails CI on a failed rule, after exporting the
  report. The
  nodes scan daily (`openscap.timer`, results in `/var/lib/openscap`), and
  list `/etc`'s drift hourly (`etc-diff.timer`, `/var/lib/etc-diff`); the
  paths the node writes on purpose are in `usr/libexec/etc-diff`.
- **grype** lists the CVEs of `/usr` and `/etc`, at build and daily on
  the nodes (`grype.timer`, `/var/lib/grype`), with `usr/libexec/grype-scan`.
  `grype.prom` holds the fixable ones of Medium severity and above;
  the `check` stage fails on a fixable Critical. One
  the image can't fix is ignored in `sysroot/system/usr/share/grype/ignore.yaml`,
  at the package's exact version, with its reason.
- **Checks:** in the layer that ships what they check: what holds for
  the image's files in `test/<layer>/build.yaml` (goss, at every build,
  CI included), what needs the booted node in
  `test/<layer>/<suite>.yaml` (goss, `test.sh`). A Containerfile `grep` only guards the
  `sed` before it.
- **Renovate** proposes `BASE` and `KUBERNETES`, the Cilium of `vm.sh`
  and `disk-images.sh`'s `disk_images_commit` (`renovate.json5`),
  automerged once every check is green (`vm-test` runs the build check)
  but for a new `BASE_VERSION` major, a Kubernetes minor (both new tags)
  or a Cilium major: review those by hand. The GPU image's
  `NVIDIA_DRIVER` and `NVIDIA_CONTAINER_TOOLKIT` (`REFERENCES.md`,
  "GPU image") are never automerged: only a GPU node runs them.

## Layout

- `Containerfile`, `sysroot/<layer>/`: the image (`system`, `kube`,
  `vm`, `metal`).
- `docker-bake.hcl`: the targets (one pair per Kubernetes line), their
  versions and tags, the `vm-test` and `disk-image` groups.
- `workbench.sh`: a rootful podman container on an x86_64 host with KVM,
  where the disk images (`disk-images.sh`: `qemu`, `openstack`, `metal`)
  and the test VM are made, as in CI's `vm-test` job.
- `test/build.yaml`, `test/<layer>/build.yaml`, `test/<IMAGE_BASE>-build.yaml`:
  the goss checks of the build; the last picks one image's.
- `vm.sh`, `test.sh`, `test/<suite>.yaml`, `test/<layer>/<suite>.yaml`,
  `test-greenboot.sh`: a test VM in the workbench (an NVMe disk), and the
  goss suites run on it (`node`, `wx`, `cluster`), split by layer.
  `test/nvidia.yaml` is the GPU image's suite, run on a node with a GPU
  (`test.sh nvidia <user>@<host>`, with the workbench up for goss's
  binary), never on the test VM.

## Build check

CI's `vm-test` job runs these commands on the build job's amd64 image,
on every pull request; they need an x86_64 host with KVM and rootful
podman, the workbench's.

```sh
docker buildx bake -f docker-bake.hcl -f bootc/docker-bake.hcl -f bootc/fedora-coreos/docker-bake.hcl \
  --set 'fedora-coreos-1-36.platform=linux/amd64' --set 'fedora-coreos-1-36.output=type=oci,dest=/tmp/fedora-coreos.ociarchive' fedora-coreos-1-36
WORKBENCH=podman bootc/fedora-coreos/workbench.sh up
WORKBENCH=podman bootc/fedora-coreos/workbench.sh exec bash -c 'cat > /work/fedora-coreos.ociarchive' < /tmp/fedora-coreos.ociarchive
WORKBENCH=podman bootc/fedora-coreos/workbench.sh exec bash -s -- /work qemu ostree-image-signed:docker://ghcr.io/spnngl/images/fedora-coreos:44-v1.36 < bootc/fedora-coreos/disk-images.sh
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
