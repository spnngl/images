#!/usr/bin/env bash
# Tests of bootc/fedora-coreos on the test VM (vm.sh up): goss suites, in
# test/, one file per layer (system, vm, metal, kube) and suite. They
# replace capi-image-builder's goss suite (goss/rootless-role.yaml), minus
# what is cloud-init, AppArmor or Ubuntu specific.
#
# Usage: bootc/fedora-coreos/test.sh node|wx|cluster|nvidia [<user>@<host>]
#   node     the booted node: kernel, users, sshd, services, sysctls, scans
#   wx       W^X: noexec mounts and their exceptions
#   cluster  once vm.sh cluster ran: the node is Ready, runs a pod that
#            executes scripts from an emptyDir and a configMap, etcd's units
#   nvidia   a node of the GPU image, with a GPU, from <user>@<host> over
#            ssh: the VM's node checks that hold on a dedicated server, and
#            the driver's (test/nvidia.yaml). Never the test VM: it has no GPU.
# Env:    WORKBENCH, BUILD_KUBE_CONTEXT  the workbench (workbench.sh)
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

[[ ${1:-} =~ ^(node|wx|cluster|nvidia)$ ]] || die "usage: $0 node|wx|cluster|nvidia [<user>@<host>]"
[[ $1 != nvidia || -n ${2:-} ]] || die "nvidia runs on a GPU node: $0 nvidia <user>@<host>"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
cp -R bootc/fedora-coreos/test/. "${tmp}/"
# The workbench's goss: the image has none, and the VM runs the same
# Fedora release.
bootc/fedora-coreos/workbench.sh exec cat /usr/bin/goss >"${tmp}/goss" ||
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
        bootc/fedora-coreos/vm.sh ssh "sudo bash -c $(printf %q "${run}") _ $1"
fi
