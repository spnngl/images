#!/usr/bin/env bash
# Workbench of bootc/fedora-coreos: a privileged Fedora container, of the
# image's Fedora release, that builds the disk images (disk-images.sh) and runs
# the test VM (vm.sh, test.sh). Its files are in /work. Rootful podman on an
# x86_64 host with /dev/kvm: CI's vm-test job, or a Linux machine.
#
# Usage: bootc/fedora-coreos/workbench.sh up|down|exec [command...]
#        bootc/fedora-coreos/workbench.sh disks <oci-archive> <platforms> <imgref>
#   up     create the workbench if absent and install its tools
#   down   delete the workbench: its test VM and files go with it
#   exec   run a command in the workbench, or a script read from stdin when
#          there is no command, from /work
#   disks  copy the image's OCI archive into the workbench and turn it into
#          disk images there (disk-images.sh: platforms comma-separated, imgref
#          what `bootc upgrade` follows); vm.sh up boots the `qemu` one
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

# The major of BASE: osbuild of the image's release builds its disk images,
# and the pin can't drift.
release() {
    local release
    release=$(sed -n -E '/^variable "BASE"/,/^}/s/^ *default = "([0-9]+)\..*/\1/p' bootc/fedora-coreos/docker-bake.hcl)
    [[ -n ${release} ]] || die "no BASE default in bootc/fedora-coreos/docker-bake.hcl"
    echo "${release}"
}

command -v podman >/dev/null || die "podman not found, install it: sudo apt-get install podman"
[[ $(uname -m) == x86_64 ]] || die "the workbench needs an x86_64 host: the disk images and the VM are x86_64"
[[ -e /dev/kvm ]] || die "no /dev/kvm: the test VM needs KVM"
# Rootful: osbuild needs loop devices, qemu /dev/kvm.
pm=(podman)
((EUID == 0)) || pm=(sudo podman)

up() {
    "${pm[@]}" container exists "${name}" && return
    # Privileged with the host's /dev (osbuild needs the partition nodes of
    # its loop devices). --init reaps zombies: qemu and swtpm daemonize, and
    # vm.sh waits on their PIDs. Volumes: /work and the nested podman's
    # storage (test.sh greenboot) on the host's disk, not on an overlay.
    "${pm[@]}" run -d --name "${name}" --init --privileged -v /dev:/dev \
        -v "${name}-work:/work" -v "${name}-storage:/var/lib/containers" \
        -w /work "registry.fedoraproject.org/fedora:$(release)" sleep infinity >/dev/null
}
down() {
    "${pm[@]}" rm -f -t 0 "${name}" >/dev/null
    "${pm[@]}" volume rm -f "${name}-work" "${name}-storage" >/dev/null
}
run() { "${pm[@]}" exec -i -w /work "${name}" "$@"; }

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
disks)
    (($# == 4)) || die "usage: $0 disks <oci-archive> <platforms> <imgref>"
    [[ -f $2 ]] || die "$2 not found"
    run bash -c 'cat > /work/fedora-coreos.ociarchive' <"$2"
    run bash -s -- /work "$3" "$4" <bootc/fedora-coreos/disk-images.sh
    ;;
*) die "usage: $0 up|down|exec [command...]|disks <oci-archive> <platforms> <imgref>" ;;
esac
