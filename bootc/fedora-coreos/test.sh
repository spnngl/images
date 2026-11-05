#!/usr/bin/env bash
# Tests of bootc/fedora-coreos on the test VM (vm.sh up), once kubeadm and
# Cilium run in it (see PLAN.md step 3). They replace capi-image-builder's
# goss suite (goss/rootless-role.yaml), minus what is cloud-init, AppArmor or
# Ubuntu specific.
#
# Usage: bootc/fedora-coreos/test.sh image|cluster|wx
#   image    what the image ships: packages, users, sshd, sysctl, containerd
#   cluster  the node is Ready and runs a pod that executes scripts from an
#            emptyDir and a configMap
#   wx       W^X: noexec mounts and their exceptions
# Env:    BUILD_KUBE_CONTEXT  kube context of the build cluster (required)
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

[[ ${1:-} =~ ^(image|cluster|wx)$ ]] || die "usage: $0 image|cluster|wx"

# The script runs as rootless on the VM; `sudo` where root is needed. The
# helpers: `check <description> <command...>` counts failures, `k` is kubectl
# as admin.
{
    cat <<'EOF'
set -uo pipefail
fail=0
check() {
    local name="$1"
    shift
    if out=$("$@" 2>&1); then
        echo "ok   ${name}"
    else
        echo "FAIL ${name}"
        echo "${out}" | head -n 15 | sed 's/^/     /'
        fail=1
    fi
}
k() { sudo kubectl --kubeconfig /etc/kubernetes/admin.conf "$@"; }
export -f k
EOF
    cat "bootc/fedora-coreos/test/$1.sh"
    # shellcheck disable=SC2016 # Expanded on the VM.
    echo 'exit "${fail}"'
} | bootc/fedora-coreos/vm.sh ssh bash -s
