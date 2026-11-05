# fedora-coreos

Fedora CoreOS bootc image for kubeadm nodes of Cluster API clusters
(OpenStack VMs, OVHcloud dedicated servers), from
`quay.io/fedora/fedora-coreos:<BASE_VERSION>`. Sources and the reason for
each choice: [REFERENCES.md](REFERENCES.md).

## Rules

- **One image stage, not the three of `bootc/AGENTS.md`**: kubeadm nodes
  only, no k3s, no Docker. The stages after it scan it (OpenSCAP, grype);
  it is the default target. Tag `<major>-v<minor>` of `BASE_VERSION` and
  `KUBERNETES_VERSION`, the Containerfile's `ARG`s, written by
  `versions.sh` for `build.sh` and CI: a patch release keeps the tag.
- **Own `sysroot/`**; from `bootc/fedora/sysroot/common/` only the
  signature files (public key, `registries.d`), copied by the
  Containerfile (no firewalld, sshd on 22, systemd-networkd). Files that Ignition or the user
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
- **Units are enabled by links in `/usr/lib/systemd/system`** (`wants` in
  the Containerfile), never by `systemctl enable` or a preset: FCOS runs
  `systemctl preset-all` at first boot, which drops the `/etc` links no
  preset names.
- **CI** (`.github/workflows/build-bootc.yml`) builds it with BuildKit,
  as `build.sh` (podman's `/run/.containerenv` turns OpenSCAP's machine
  rules off), for amd64 and arm64; scans amd64; on `main`, pushes and
  signs `ghcr.io/spnngl/images/fedora-coreos:<major>-v<minor>` and
  releases the OpenStack qcow2 (`disk-images.sh`).
- **OpenSCAP** checks the image at build and the nodes against
  scap-security-guide's `cis_server_l1` profile, tailored in
  `sysroot/usr/share/xml/scap/fedora-coreos/tailoring.xml`: a rule the
  image doesn't follow is turned off there, with its reason beside it;
  the ones still to decide are grouped last.
  `check-reports.sh` fails `build.sh` and CI on a failed rule, after
  exporting the report. The
  nodes scan daily (`openscap.timer`, results in `/var/lib/openscap`).
- **grype** lists the CVEs of `/usr` and `/etc`, at build and daily on
  the nodes (`grype.timer`, `/var/lib/grype`), with `usr/libexec/grype-scan`.
  `grype.prom` holds the fixable ones of Medium severity and above;
  `check-reports.sh` fails on a fixable Critical. One
  the image can't fix is ignored in `sysroot/usr/share/grype/ignore.yaml`,
  at the package's exact version, with its reason.
- **Renovate** proposes `BASE_VERSION`, `KUBERNETES_VERSION`, the Cilium
  of `vm.sh` and `disk-images.sh`'s `disk_images_commit` (`renovate.json5`),
  automerged only for a `BASE_VERSION` of the same major, once CI is
  green; run the build check before merging any other.

## Layout

- `Containerfile`, `sysroot/`: the image.
- `build.sh`: container image and its scan reports
  (`output/fedora-coreos/reports/`) on the cluster's BuildKit, then disk
  images (`qemu`, `openstack`, `metal`) in the workbench pod
  (`workbench.yaml`, `workbench.sh`).
- `versions.sh`, `check-reports.sh`, `disk-images.sh`: the tag, the scan
  gate and the disk images, shared by `build.sh` and CI.
- `vm.sh`, `test.sh`, `test/`, `test-greenboot.sh`: a
  test VM in the workbench (an NVMe disk), and the checks run on it.
- `ignition-converter/`: Go webhook that turns CABPK's Ignition spec 2.3
  into 3.0, with its own [README.md](ignition-converter/README.md).

## Build check

`BUILD_KUBE_CONTEXT` is the kube context of the build cluster, which runs the BuildKit and the workbench.

```sh
export BUILD_KUBE_CONTEXT=<context>
bootc/fedora-coreos/build.sh qemu,openstack,metal
bootc/fedora-coreos/vm.sh up
bootc/fedora-coreos/test.sh image     # packages, config, units, sshd, sysctls, OpenSCAP, grype
bootc/fedora-coreos/vm.sh cluster     # kubeadm init + Cilium
bootc/fedora-coreos/test.sh cluster   # node Ready, pod runs scripts from emptyDir and configMap
bootc/fedora-coreos/test.sh wx        # noexec everywhere but the exceptions
bootc/fedora-coreos/test-greenboot.sh # good update kept, bad one rolled back
bootc/fedora-coreos/ignition-converter/e2e.sh
(cd bootc/fedora-coreos/ignition-converter && go vet ./... && go test ./...)
bootc/fedora-coreos/vm.sh down
bootc/fedora-coreos/workbench.sh down
```

Done when each command exits 0. Run `test.sh wx` again after a reboot.
