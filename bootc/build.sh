#!/usr/bin/env bash
# Build a bootc container image with Bake, then turn it into a qcow2 disk
# image with image-builder.
#
# Usage: bootc/build.sh [id]    (default: fedora-45)
# id:     a target of bootc/*/docker-bake.hcl: `docker buildx bake -f
#         docker-bake.hcl -f bootc/docker-bake.hcl ... --list` names them.
# Image:  the target's first tag, ghcr.io/spnngl/images/<name>:<tag>: the
#         one CI pushes (.github/workflows/build-bootc.yml). Not pushed.
# Output: output/<id>/<id>.qcow2
#
# Needs docker buildx (the build), rootful podman (image-builder reads the
# image from its storage) and ./config.toml, the image-builder blueprint.
set -euo pipefail

id="${1:-fedora-45}"
cd "$(dirname "$0")/.."

die() {
    echo "error: $*" >&2
    exit 1
}

command -v docker > /dev/null || die "docker not found: install docker with its buildx plugin"
command -v podman > /dev/null || die "podman not found: install podman"
[[ -f config.toml ]] || die "config.toml not found, start from: cp bootc/config.example.toml config.toml"
[[ "$(podman info --format '{{.Host.Security.Rootless}}')" == false ]] ||
    die "podman is rootless, on macOS run: podman machine stop; podman machine set --rootful; podman machine start"

bake=(docker buildx bake -f docker-bake.hcl -f bootc/docker-bake.hcl)
for file in bootc/*/docker-bake.hcl; do
    bake+=(-f "${file}")
done
tag="$("${bake[@]}" --print "${id}" 2> /dev/null | jq -r --arg id "${id}" '.target[$id].tags[0] // empty')"
[[ -n ${tag} ]] || die "${id} is not an image of bootc/*/docker-bake.hcl"

# The host's platform only: image-builder builds a disk for it. Through a
# tar file: podman's storage, not docker's, is where image-builder looks.
# Bake pushes nothing by itself.
case "$(uname -m)" in
    x86_64) platform=linux/amd64 ;;
    aarch64 | arm64) platform=linux/arm64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
esac
tar="$(mktemp)"
trap 'rm -f "${tar}"' EXIT
"${bake[@]}" --set "${id}.platform=${platform}" --set "${id}.output=type=docker,dest=${tar}" "${id}"
podman load -i "${tar}"

# --privileged and label=type:unconfined_t: image-builder relabels files and
# sets up loop devices, which a confined container is not allowed to do.
# /var/lib/containers/storage: lets image-builder see the image built above.
mkdir -p output
podman run --rm --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "${PWD}/config.toml:/config.toml:ro" \
    -v "${PWD}/output:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    ghcr.io/osbuild/image-builder-cli:v90.0.0 \
    build --bootc-ref "${tag}" --blueprint /config.toml \
    --output-dir "${id}" --output-name "${id}" qcow2

echo "disk image: output/${id}/${id}.qcow2"
