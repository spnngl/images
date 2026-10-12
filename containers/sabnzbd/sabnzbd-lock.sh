#!/usr/bin/env bash
# Regenerate containers/sabnzbd/requirements.lock: SABnzbd's
# requirements.txt at the BASE_VERSION of docker-bake.hcl, every module
# (sub-dependencies too) pinned to one version and to the hashes of its
# files on PyPI. The image build installs exactly these files (uv pip
# install --require-hashes).
#
# Usage: containers/sabnzbd/sabnzbd-lock.sh    (after bumping BASE_VERSION
#        or UV_VERSION in containers/sabnzbd/docker-bake.hcl, or to update
#        unpinned modules such as cryptography)
#
# Requirements: docker, curl, jq.
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

command -v docker >/dev/null || die "docker not found, install Docker: https://docs.docker.com/get-docker/"
command -v curl >/dev/null || die "curl not found, install it with your package manager"
command -v jq >/dev/null || die "jq not found, install it with your package manager"
# Read the versions Bake passes.
args="$(docker buildx bake -f containers/docker-bake.hcl -f containers/sabnzbd/docker-bake.hcl --print "*" 2>/dev/null | jq -c '.target[].args')"
version="$(jq -r .BASE_VERSION <<<"${args}")"
uv_version="$(jq -r .UV_VERSION <<<"${args}")"
[[ -n ${version} && -n ${uv_version} ]] || die "containers/sabnzbd/docker-bake.hcl has no BASE_VERSION or UV_VERSION"

# notify2: desktop notifications over D-Bus, which the image doesn't have.
# --python-version: Debian trixie's python3, the image's. --python-platform:
# Linux only, without the Windows and macOS modules.
curl -fsSL "https://raw.githubusercontent.com/sabnzbd/sabnzbd/${version}/requirements.txt" |
    grep -v '^notify2' |
    docker run --rm -i "ghcr.io/astral-sh/uv:${uv_version}-trixie-slim" \
        uv pip compile --quiet --python-version 3.13 --python-platform linux \
        --generate-hashes --custom-compile-command "containers/sabnzbd/sabnzbd-lock.sh" - \
        >containers/sabnzbd/requirements.lock
