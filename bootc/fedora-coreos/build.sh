#!/usr/bin/env bash
# Build the amd64 bootc image of bootc/fedora-coreos on the cluster's BuildKit,
# then turn it into disk images in the workbench pod.
#
# Usage: bootc/fedora-coreos/build.sh <platform>[,<platform>...]
#   platform: qemu (test VM), openstack (qcow2), metal (raw, dedicated servers)
# Env:    BUILD_KUBE_CONTEXT  kube context of the build cluster (required)
# Image:  ghcr.io/spnngl/images/fedora-coreos:<IMAGE_TAG> (versions.sh), as
#         CI's (build-bootc.yml). Not pushed: the archive stays in the
#         workbench (/work/fedora-coreos.ociarchive) for `bootc switch`.
# Output: output/fedora-coreos/fedora-coreos-<platform>.x86_64.{qcow2,raw}
#         output/fedora-coreos/reports/openscap/{results.xml,report.html}
#         output/fedora-coreos/reports/grype/{grype.json,grype.prom}
#
# Why this way, and why on a cluster: bootc/fedora-coreos/REFERENCES.md.
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

platforms="${1:-}"
[[ -n ${platforms} ]] || die "usage: $0 <platform>[,<platform>...] (qemu, openstack, metal)"
[[ ${platforms} =~ ^(qemu|openstack|metal)(,(qemu|openstack|metal))*$ ]] ||
    die "unknown platform in '${platforms}': use qemu, openstack and metal"
command -v docker >/dev/null || die "docker not found, install it with Docker Desktop or: brew install docker docker-buildx"
docker buildx version >/dev/null 2>&1 || die "docker buildx not found, install it: brew install docker-buildx"
command -v kubectl >/dev/null || die "kubectl not found, install it: brew install kubectl"
[[ -n ${BUILD_KUBE_CONTEXT:-} ]] || die "BUILD_KUBE_CONTEXT is unset, set it to the kube context of the build cluster"

containerfile=bootc/fedora-coreos/Containerfile
# shellcheck source=/dev/null
source <(bootc/fedora-coreos/versions.sh)
image="ghcr.io/spnngl/images/fedora-coreos:${IMAGE_TAG}"

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
# The scans first: a failed OpenSCAP rule or a fixable Critical vulnerability
# stops here, with the reports. The build context is the image's own folder.
reports="${out}/reports"
rm -rf "${reports}"
docker buildx build --builder "${builder}" --platform linux/amd64 \
    --file "${containerfile}" --target reports --output "type=local,dest=${reports}" bootc/fedora-coreos/
bootc/fedora-coreos/check-reports.sh "${reports}"

# The image, from the builder's cache.
docker buildx build --builder "${builder}" --platform linux/amd64 \
    --file "${containerfile}" --output "type=oci,dest=${archive}" bootc/fedora-coreos/

"${workbench}" up
"${workbench}" exec bash -c 'cat > /work/fedora-coreos.ociarchive' <"${archive}"

# --imgref is what `bootc upgrade` follows: CI's signed image of the same
# tag. The script's default names the archive, absent from the node.
"${workbench}" exec bash -s -- /work "${platforms}" "ostree-image-signed:docker://${image}" \
    <bootc/fedora-coreos/disk-images.sh

for platform in ${platforms//,/ }; do
    case "${platform}" in
    metal) suffix=raw ;;
    *) suffix=qcow2 ;;
    esac
    file="fedora-coreos-${platform}.x86_64.${suffix}"
    "${workbench}" exec cat "/work/${file}" >"${out}/${file}" </dev/null
    echo "disk image: ${out}/${file}"
done
