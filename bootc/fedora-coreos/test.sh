#!/usr/bin/env bash
# Tests of bootc/fedora-coreos on the test VM (vm.sh up): goss suites, in
# test/, one file per layer (system, vm, metal, kube) and suite. They
# replace capi-image-builder's goss suite (goss/rootless-role.yaml), minus
# what is cloud-init, AppArmor or Ubuntu specific.
#
# Usage: bootc/fedora-coreos/test.sh node|wx|cluster|greenboot|nvidia [<user>@<host>]
#   node     the booted node: kernel, users, sshd, services, sysctls, scans
#   wx       W^X: noexec mounts and their exceptions
#   cluster  once vm.sh cluster ran: the node is Ready, runs a pod that
#            executes scripts from an emptyDir and a configMap, etcd's units
#   greenboot  an update that boots is kept, and one that fails a required
#            check is rolled back. It needs the archive the build check copied
#            into the workbench (/work/fedora-coreos.ociarchive). Both updates
#            are that image plus one layer, built in the workbench, copied into
#            the VM and applied with `bootc switch`:
#              good  adds a marker file
#              bad   adds a required check that fails
#   nvidia   a node of the GPU image, with a GPU, from <user>@<host> over
#            ssh: the VM's node checks that hold on a dedicated server, and
#            the driver's (test/nvidia.yaml). Never the test VM: it has no GPU.
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

[[ ${1:-} =~ ^(node|wx|cluster|greenboot|nvidia)$ ]] || die "usage: $0 node|wx|cluster|greenboot|nvidia [<user>@<host>]"
[[ $1 != nvidia || -n ${2:-} ]] || die "nvidia runs on a GPU node: $0 nvidia <user>@<host>"

workbench=bootc/fedora-coreos/workbench.sh
vm=bootc/fedora-coreos/vm.sh

greenboot() {
    # The image that the VM booted, from `bootc status`.
    booted() { "${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.image.image'; }

    step() { echo "== $*"; }

    step "build the two updates in the workbench"
    "${workbench}" exec <<'EOF'
set -euo pipefail
cd /work/vm
# An empty build context: /work/vm holds the VM's disks, which podman would
# copy for nothing.
ctx=$(mktemp -d)
for variant in good bad; do
    case "${variant}" in
    good) run="touch /usr/share/greenboot-test-good" ;;
    bad) run="printf '#!/bin/bash\nexit 1\n' > /usr/lib/greenboot/check/required.d/99-fail.sh && chmod +x /usr/lib/greenboot/check/required.d/99-fail.sh" ;;
    esac
    printf 'FROM oci-archive:/work/fedora-coreos.ociarchive\nRUN %s\n' "${run}" > "${ctx}/Containerfile.${variant}"
    podman build -q -f "${ctx}/Containerfile.${variant}" -t "localhost/update-${variant}" "${ctx}"
    rm -f "${variant}.ociarchive"
    podman save --format oci-archive -o "${variant}.ociarchive" "localhost/update-${variant}" 2>/dev/null
    scp -q -i key -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${variant}.ociarchive" rootless@127.0.0.1:/var/tmp/
    rm -f "${variant}.ociarchive"
done
rm -rf "${ctx}"
EOF

    step "before: greenboot passed on this boot"
    "${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
    before=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')

    step "good update: boots, and greenboot marks it successful"
    "${vm}" ssh 'sudo bootc switch --transport oci-archive /var/tmp/good.ociarchive'
    "${vm}" reboot
    "${vm}" ssh 'test -e /usr/share/greenboot-test-good'
    sleep 30
    "${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
    good=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')
    [[ ${good} != "${before}" ]] || die "the VM booted the same image after the good update"

    step "bad update: greenboot reboots GREENBOOT_MAX_BOOT_ATTEMPTS times, then rolls back"
    "${vm}" ssh 'sudo bootc switch --transport oci-archive /var/tmp/bad.ociarchive'
    "${vm}" reboot
    # The failing boots reboot the VM by themselves; wait for the one that stays.
    for _ in $(seq 60); do
        sleep 10
        if "${vm}" ssh '! test -e /usr/lib/greenboot/check/required.d/99-fail.sh' 2>/dev/null; then
            break
        fi
    done
    sleep 30
    now=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')
    [[ ${now} == "${good}" ]] || die "expected to be back on the good image (${good}), booted ${now}"
    "${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
    "${vm}" ssh 'sudo journalctl --no-pager -u greenboot-healthcheck -u greenboot-set-rollback-trigger | tail -n 30'
    echo "ok: the good update is kept ($(booted)), the bad one is rolled back"
}

if [[ $1 == greenboot ]]; then
    greenboot
    exit
fi

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
cp -R bootc/fedora-coreos/test/. "${tmp}/"
# The workbench's goss: the image has none, and the VM runs the same
# Fedora release.
"${workbench}" exec cat /usr/bin/goss >"${tmp}/goss" ||
    die "no goss in the workbench, run: bootc/fedora-coreos/workbench.sh up"
chmod 0755 "${tmp}/goss"

# Runs as root on the VM, the suite's files on stdin. W^X makes every
# writable mount noexec: goss runs from a tmpfs of its own, exec, that
# goes away with the run. One check at a time: some change state, then
# restore it. cluster retries the whole suite for 4 minutes: after a
# boot, the API, then Cilium, come up after sshd, while the node still
# shows Ready from before it (goss runs checks in no set order).
# shellcheck disable=SC2016 # Expanded on the VM.
run='set -euo pipefail
retry=()
if [[ $1 == cluster ]]; then retry=(--retry-timeout 240s --sleep 10s); fi
d=/run/goss
if mountpoint -q "${d}"; then umount "${d}"; fi
mkdir -p "${d}"
mount -t tmpfs -o mode=0700,nosuid,nodev,size=64m tmpfs "${d}"
trap "cd / && umount ${d}" EXIT
tar -x --no-same-owner -C "${d}"
cd "${d}"
KUBECONFIG=/etc/kubernetes/admin.conf ./goss --gossfile "$1.yaml" validate \
    "${retry[@]}" --max-concurrent 1 --format documentation --no-color'

# ustar, no macOS metadata: GNU tar on the VM reads it without warnings.
# nvidia: the node is a real one, reached from here, not through the
# workbench's qemu.
if [[ $1 == nvidia ]]; then
    # shellcheck disable=SC2029 # The script is quoted here, on purpose.
    COPYFILE_DISABLE=1 tar --format ustar -C "${tmp}" -cf - . |
        ssh "$2" "sudo bash -c $(printf %q "${run}") _ $1"
else
    COPYFILE_DISABLE=1 tar --format ustar -C "${tmp}" -cf - . |
        "${vm}" ssh "sudo bash -c $(printf %q "${run}") _ $1"
fi
