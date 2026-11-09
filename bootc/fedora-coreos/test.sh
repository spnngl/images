#!/usr/bin/env bash
# Tests of bootc/fedora-coreos on the test VM (vm.sh up): goss suites, in
# test/, one file per layer (system, vm, metal, kube) and suite. They
# replace capi-image-builder's goss suite (goss/rootless-role.yaml), minus
# what is cloud-init, AppArmor or Ubuntu specific.
#
# Usage: bootc/fedora-coreos/test.sh node|wx|cluster
#   node     the booted node: kernel, users, sshd, services, sysctls, scans
#   wx       W^X: noexec mounts and their exceptions
#   cluster  once vm.sh cluster ran: the node is Ready, runs a pod that
#            executes scripts from an emptyDir and a configMap, etcd's units
# Env:    WORKBENCH, BUILD_KUBE_CONTEXT  the workbench (workbench.sh)
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

[[ ${1:-} =~ ^(node|wx|cluster)$ ]] || die "usage: $0 node|wx|cluster"

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
# restore it.
# shellcheck disable=SC2016 # Expanded on the VM.
run='set -euo pipefail
d=/run/goss
if mountpoint -q "${d}"; then umount "${d}"; fi
mkdir -p "${d}"
mount -t tmpfs -o mode=0700,nosuid,nodev,size=64m tmpfs "${d}"
trap "cd / && umount ${d}" EXIT
tar -x --no-same-owner -C "${d}"
cd "${d}"
KUBECONFIG=/etc/kubernetes/admin.conf ./goss --gossfile "$1.yaml" validate \
    --max-concurrent 1 --format documentation --no-color'

# ustar, no macOS metadata: GNU tar on the VM reads it without warnings.
COPYFILE_DISABLE=1 tar --format ustar -C "${tmp}" -cf - . |
    bootc/fedora-coreos/vm.sh ssh "sudo bash -c $(printf %q "${run}") _ $1"
