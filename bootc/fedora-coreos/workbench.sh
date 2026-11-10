#!/usr/bin/env bash
# Workbench of bootc/fedora-coreos: a privileged Fedora container, of the
# image's Fedora release, that builds the disk images (disk-images.sh) and runs
# the test VM (vm.sh, test.sh, test-greenboot.sh). Its files are in /work.
#
# Usage: bootc/fedora-coreos/workbench.sh up|down|exec [command...]
#   up    create the workbench if absent and install its tools
#   down  delete the workbench: its test VM and files go with it
#   exec  run a command in the workbench, or a script read from stdin when
#         there is no command, from /work
# Env:    WORKBENCH  backend (default kube):
#           kube    a pod on the build cluster (workbench.yaml, local and
#                   git-ignored: it names the cluster); needs
#                   BUILD_KUBE_CONTEXT, its kube context
#           podman  a rootful container on this host (CI's vm-test job);
#                   needs x86_64 and /dev/kvm
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

name=fcos-workbench

# Tools of custom-coreos-disk-images.sh's header, plus qemu and OVMF for
# vm.sh (swtpm: its TPM), butane for the Ignition fixtures, podman to
# inspect images, and goss for test.sh (it copies the binary into the VM).
packages=(
    osbuild osbuild-tools osbuild-ostree podman jq xfsprogs e2fsprogs
    dosfstools genisoimage squashfs-tools erofs-utils syslinux-nonlinux
    git skopeo tar qemu-system-x86-core edk2-ovmf butane openssh-clients
    openssh-server helm swtpm goss
)

# The major of BASE_VERSION: osbuild of the image's release builds its
# disk images, and the pin can't drift.
release() {
    local release
    release=$(sed -n -E '/^variable "BASE"/,/^}/s/^ *default = "([0-9]+)\..*/\1/p' bootc/fedora-coreos/docker-bake.hcl)
    [[ -n ${release} ]] || die "no BASE default in bootc/fedora-coreos/docker-bake.hcl"
    echo "${release}"
}

case "${WORKBENCH:-kube}" in
kube)
    command -v kubectl >/dev/null || die "kubectl not found, install it: brew install kubectl"
    [[ -n ${BUILD_KUBE_CONTEXT:-} ]] || die "BUILD_KUBE_CONTEXT is unset, set it to the kube context of the build cluster"
    kc=(kubectl --context "${BUILD_KUBE_CONTEXT}" --namespace gitlab-shared-runners)
    up() {
        # A pod past its activeDeadlineSeconds (workbench.yaml), or whose
        # node went away, is Failed for good: replace it.
        local phase
        phase=$("${kc[@]}" get pod "${name}" -o jsonpath='{.status.phase}' 2>/dev/null || true)
        if [[ ${phase} == Failed || ${phase} == Succeeded ]]; then
            "${kc[@]}" delete pod "${name}" --wait=true
            phase=""
        fi
        if [[ -z ${phase} ]]; then
            [[ -f bootc/fedora-coreos/workbench.yaml ]] ||
                die "bootc/fedora-coreos/workbench.yaml not found: it is local (git-ignored); or use WORKBENCH=podman on an x86_64 host with /dev/kvm"
            sed "s/FEDORA_RELEASE/$(release)/" bootc/fedora-coreos/workbench.yaml | "${kc[@]}" apply -f -
        fi
        "${kc[@]}" wait --for=condition=Ready "pod/${name}" --timeout=300s
    }
    down() { "${kc[@]}" delete pod "${name}" --ignore-not-found --wait=true; }
    run() { "${kc[@]}" exec -i "${name}" -- "$@"; }
    ;;
podman)
    command -v podman >/dev/null || die "podman not found, install it: sudo apt-get install podman"
    [[ $(uname -m) == x86_64 ]] || die "WORKBENCH=podman needs an x86_64 host: the disk images and the VM are x86_64"
    [[ -e /dev/kvm ]] || die "no /dev/kvm: the test VM needs KVM"
    # Rootful: osbuild needs loop devices, qemu /dev/kvm.
    pm=(podman)
    ((EUID == 0)) || pm=(sudo podman)
    up() {
        "${pm[@]}" container exists "${name}" && return
        # As workbench.yaml: privileged with the host's /dev (osbuild needs
        # the partition nodes of its loop devices). --init reaps zombies:
        # qemu and swtpm daemonize, and vm.sh waits on their PIDs. Volumes:
        # /work and the nested podman's storage (test-greenboot.sh) on the
        # host's disk, not on an overlay.
        "${pm[@]}" run -d --name "${name}" --init --privileged -v /dev:/dev \
            -v "${name}-work:/work" -v "${name}-storage:/var/lib/containers" \
            -w /work "registry.fedoraproject.org/fedora:$(release)" sleep infinity >/dev/null
    }
    down() {
        "${pm[@]}" rm -f -t 0 "${name}" >/dev/null
        "${pm[@]}" volume rm -f "${name}-work" "${name}-storage" >/dev/null
    }
    run() { "${pm[@]}" exec -i -w /work "${name}" "$@"; }
    ;;
*) die "WORKBENCH must be kube or podman, not ${WORKBENCH}" ;;
esac

case "${1:-}" in
up)
    up
    # Re-running dnf is cheap once installed.
    run dnf -y -q install "${packages[@]}"
    ;;
down) down ;;
exec)
    shift
    if (($# > 0)); then
        run "$@"
    else
        run bash -s
    fi
    ;;
*) die "usage: $0 up|down|exec [command...]" ;;
esac
