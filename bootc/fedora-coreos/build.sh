#!/usr/bin/env bash
# Build the amd64 bootc image of bootc/fedora-coreos on the cluster's BuildKit,
# then turn it into disk images in the workbench pod.
#
# Usage: bootc/fedora-coreos/build.sh <platform>[,<platform>...]
#   platform: qemu (test VM), openstack (qcow2), metal (raw, dedicated servers)
# Env:    BUILD_KUBE_CONTEXT  kube context of the build cluster (required)
# Image:  ghcr.io/spnngl/images/fedora-coreos:<BASE_VERSION>-v<KUBERNETES_VERSION>,
#         both from the Containerfile. Not pushed: the archive stays in the
#         workbench (/work/fedora-coreos.ociarchive) for `bootc switch`.
# Output: output/fedora-coreos/fedora-coreos-<platform>.x86_64.{qcow2,raw}
#
# Why this way, and why on a cluster: bootc/fedora-coreos/REFERENCES.md.
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

# A commit of main (no release), proposed weekly by Renovate (renovate.json5).
disk_images_commit="12f696dfec3b4f7fe3c8748433aa2627c0f97367"

platforms="${1:-}"
[[ -n ${platforms} ]] || die "usage: $0 <platform>[,<platform>...] (qemu, openstack, metal)"
[[ ${platforms} =~ ^(qemu|openstack|metal)(,(qemu|openstack|metal))*$ ]] ||
    die "unknown platform in '${platforms}': use qemu, openstack and metal"
command -v docker >/dev/null || die "docker not found, install it with Docker Desktop or: brew install docker docker-buildx"
docker buildx version >/dev/null 2>&1 || die "docker buildx not found, install it: brew install docker-buildx"
command -v kubectl >/dev/null || die "kubectl not found, install it: brew install kubectl"
[[ -n ${BUILD_KUBE_CONTEXT:-} ]] || die "BUILD_KUBE_CONTEXT is unset, set it to the kube context of the build cluster"

containerfile=bootc/fedora-coreos/Containerfile
arg() {
    sed -n -E "s/^ARG $1=\"?([^\"[:space:]]+)\"?.*/\1/p" "${containerfile}"
}
base_version="$(arg BASE_VERSION)"
kubernetes_version="$(arg KUBERNETES_VERSION)"
[[ -n ${base_version} && -n ${kubernetes_version} ]] ||
    die "${containerfile} needs ARG BASE_VERSION and ARG KUBERNETES_VERSION"
image="ghcr.io/spnngl/images/fedora-coreos:${base_version}-v${kubernetes_version}"

workbench=bootc/fedora-coreos/workbench.sh
builder="fcos-build-$$"
out=output/fedora-coreos
archive="${out}/fedora-coreos.ociarchive"

port_forward_pid=""
cleanup() {
    docker buildx rm --force "${builder}" >/dev/null 2>&1 || true
    if [[ -n ${port_forward_pid} ]]; then
        kill "${port_forward_pid}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# The cluster's BuildKit (the shared GitLab runners') is the only amd64 builder
# at hand: the Mac is arm64.
# Port 0: kubectl picks a free local port and prints it.
forward_log=$(mktemp)
kubectl --context "${BUILD_KUBE_CONTEXT}" --namespace gitlab-shared-runners \
    port-forward svc/buildkitd :12345 >"${forward_log}" &
port_forward_pid=$!
port=""
for _ in $(seq 30); do
    port=$(sed -n -E 's/^Forwarding from 127\.0\.0\.1:([0-9]+) .*/\1/p' "${forward_log}")
    [[ -n ${port} ]] && (exec 3<>"/dev/tcp/127.0.0.1/${port}") 2>/dev/null && break
    port=""
    sleep 1
done
rm -f "${forward_log}"
[[ -n ${port} ]] || die "no port-forward to svc/buildkitd after 30 s"
docker buildx create --name "${builder}" --driver remote "tcp://127.0.0.1:${port}" >/dev/null

mkdir -p "${out}"
# The build context is bootc/, shared by every bootc image.
docker buildx build --builder "${builder}" --platform linux/amd64 \
    --file "${containerfile}" --output "type=oci,dest=${archive}" bootc/

"${workbench}" up
"${workbench}" exec bash -c 'cat > /work/fedora-coreos.ociarchive' <"${archive}"

# `exec` with no command runs stdin as a script. The commit is pinned: its
# cosa-imports hold the osbuild manifests.
# --imgref is what `bootc upgrade` follows. The script's default names the
# archive, absent from the node, and requires a signature our images lack.
# --extra-kargs: the script's default for Fedora CoreOS, mitigations=auto,nosmt,
# turns off half the CPUs; mitigations=auto is the kernel's default.
"${workbench}" exec <<EOF
set -euxo pipefail
cd /work
if [ ! -d custom-coreos-disk-images ]; then
    git clone https://github.com/coreos/custom-coreos-disk-images
fi
# A clone from an earlier run lacks a commit that Renovate bumped to.
git -C custom-coreos-disk-images fetch --quiet origin ${disk_images_commit}
git -C custom-coreos-disk-images checkout --quiet ${disk_images_commit}
rm -f fedora-coreos-*.x86_64.*
custom-coreos-disk-images/custom-coreos-disk-images.sh \\
    --osname fedora-coreos \\
    --ociarchive /work/fedora-coreos.ociarchive \\
    --platforms ${platforms} \\
    --imgref ostree-unverified-registry:${image} \\
    --extra-kargs mitigations=auto
EOF

for platform in ${platforms//,/ }; do
    case "${platform}" in
    metal) suffix=raw ;;
    *) suffix=qcow2 ;;
    esac
    file="fedora-coreos-${platform}.x86_64.${suffix}"
    "${workbench}" exec cat "/work/${file}" >"${out}/${file}" </dev/null
    echo "disk image: ${out}/${file}"
done
