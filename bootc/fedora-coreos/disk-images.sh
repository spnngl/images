#!/usr/bin/env bash
# Turn the image's OCI archive into disk images with custom-coreos-disk-images.
# Runs as root in a privileged container of the image's Fedora release:
# build.sh's workbench (from stdin, `bash -s --`) and build-bootc.yml's
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

# The kernel arguments of the image's usr/lib/bootc/kargs.d, by bootc's rules
# (crates/lib/src/bootc_kargs.rs): its *.toml files in name order, those
# matching this machine's architecture, the disk's. osbuild's
# org.osbuild.ostree.deploy.container stage doesn't read them, and bootc
# upgrade only adds the ones the booted image lacks: a disk without them
# would never get them. Read from the archive's layers: nested podman can't
# store the image here.
image_kargs=$(
    python3 - fedora-coreos.ociarchive <<'EOF'
import json, platform, sys, tarfile, tomllib

KARGS_D = "usr/lib/bootc/kargs.d"
arch = {"x86_64": "amd64", "aarch64": "arm64"}[platform.machine()]

with tarfile.open(sys.argv[1]) as archive:
    def blob(descriptor):
        return archive.extractfile("blobs/" + descriptor["digest"].replace(":", "/"))

    # skopeo's archive: index.json names the manifest. buildx's: an index
    # of the image's manifest and its attestation's (platform unknown).
    document = json.load(archive.extractfile("index.json"))
    while "manifests" in document:
        document = json.load(blob(next(
            m for m in document["manifests"]
            if m.get("platform", {}).get("architecture", arch) == arch
        )))
    files = {}
    for layer in document["layers"]:
        with tarfile.open(fileobj=blob(layer), mode="r|*") as tar:
            for member in tar:
                directory, _, name = member.name.removeprefix("./").rpartition("/")
                if directory != KARGS_D:
                    continue
                # OCI whiteouts: a later layer deletes a file, or every file.
                if name == ".wh..wh..opq":
                    files.clear()
                elif name.startswith(".wh."):
                    files.pop(name.removeprefix(".wh."), None)
                elif member.isfile():
                    files[name] = tar.extractfile(member).read()

kargs = []
for name in sorted(files):
    if name.endswith(".toml"):
        config = tomllib.loads(files[name].decode())
        if platform.machine() in config.get("match-architectures", [platform.machine()]):
            kargs += config["kargs"]
print(" ".join(kargs))
EOF
)
[[ -n ${image_kargs} ]] || {
    echo "no kernel argument in the image's usr/lib/bootc/kargs.d" >&2
    exit 1
}

rm -f fedora-coreos-*.qcow2 fedora-coreos-*.raw
# --extra-kargs: the image's, and mitigations=auto (the kernel's default)
# instead of the script's default for Fedora CoreOS, mitigations=auto,nosmt,
# which turns off half the CPUs. ostree splits them on spaces.
custom-coreos-disk-images/custom-coreos-disk-images.sh \
    --osname fedora-coreos \
    --ociarchive "${PWD}/fedora-coreos.ociarchive" \
    --platforms "${platforms}" \
    --imgref "${imgref}" \
    --extra-kargs "mitigations=auto ${image_kargs}"

# osbuild writes the qcow2 files uncompressed; compressed, they still boot
# as they are, and a release asset must stay under 2 GiB.
for file in fedora-coreos-*.qcow2; do
    [[ -e ${file} ]] || continue
    qemu-img convert -c -O qcow2 "${file}" "${file}.tmp"
    mv "${file}.tmp" "${file}"
done
