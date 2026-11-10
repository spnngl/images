#!/usr/bin/env bash
# Turn the image's OCI archive into disk images with custom-coreos-disk-images.
# Runs as root in a privileged container of the image's Fedora release:
# the workbench (from stdin, `bash -s --`) and build-bootc.yml's
# disk-image job (mounted).
#
# Usage: disk-images.sh <dir> <platforms> <imgref>
#   dir        holds fedora-coreos.ociarchive, and gets the disk images:
#              fedora-coreos-<platform>.<arch>.{qcow2,raw}
#   platforms  comma-separated: qemu, openstack, metal
#   imgref     what `bootc upgrade` follows
set -euo pipefail

# A commit of main (no release), proposed weekly by Renovate (renovate.json5).
disk_images_commit="12f696dfec3b4f7fe3c8748433aa2627c0f97367"

if (($# != 3)); then
    echo "usage: disk-images.sh <dir> <platforms> <imgref>" >&2
    exit 1
fi
dir="$1"
platforms="$2"
imgref="$3"

# The tools of custom-coreos-disk-images.sh's header, git to fetch it, and
# qemu-img to compress the qcow2 files.
dnf -yq install osbuild osbuild-tools osbuild-ostree podman jq xfsprogs e2fsprogs \
    dosfstools genisoimage squashfs-tools erofs-utils syslinux-nonlinux git qemu-img

cd "${dir}"
if [[ ! -d custom-coreos-disk-images ]]; then
    git clone --quiet https://github.com/coreos/custom-coreos-disk-images
fi
# A clone from an earlier run lacks a commit that Renovate bumped to. The
# commit's cosa-imports hold the osbuild manifests.
git -C custom-coreos-disk-images fetch --quiet origin "${disk_images_commit}"
git -C custom-coreos-disk-images checkout --quiet "${disk_images_commit}"

rm -f fedora-coreos-*.qcow2 fedora-coreos-*.raw
# --extra-kargs: the script's default for Fedora CoreOS, mitigations=auto,nosmt,
# turns off half the CPUs; mitigations=auto is the kernel's default.
custom-coreos-disk-images/custom-coreos-disk-images.sh \
    --osname fedora-coreos \
    --ociarchive "${PWD}/fedora-coreos.ociarchive" \
    --platforms "${platforms}" \
    --imgref "${imgref}" \
    --extra-kargs mitigations=auto

# osbuild writes the qcow2 files uncompressed; compressed, they still boot
# as they are, and a release asset must stay under 2 GiB.
for file in fedora-coreos-*.qcow2; do
    [[ -e ${file} ]] || continue
    qemu-img convert -c -O qcow2 "${file}" "${file}.tmp"
    mv "${file}.tmp" "${file}"
done
