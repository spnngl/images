#!/usr/bin/env bash
# Regenerate images/sabnzbd/requirements.lock: SABnzbd's requirements.txt at
# the spec's BASE_VERSION, every module (sub-dependencies too) pinned to one
# version and to the hashes of its files on PyPI. The image build installs
# exactly these files (uv pip install --require-hashes).
#
# Usage: scripts/sabnzbd-lock.sh    (after bumping BASE_VERSION or UV_VERSION
#        in images/sabnzbd/spec.yml, or to update unpinned modules such as
#        cryptography)
#
# Requirements: docker, curl.
set -euo pipefail

cd "$(dirname "$0")/.."

die() {
    echo "error: $*" >&2
    exit 1
}

spec="images/sabnzbd/spec.yml"
command -v docker >/dev/null || die "docker not found, install Docker: https://docs.docker.com/get-docker/"
command -v curl >/dev/null || die "curl not found, install it with your package manager"
arg() {
    sed -n -E "s/^  $1: ([^[:space:]]+).*/\1/p" "${spec}"
}
version="$(arg BASE_VERSION)"
uv_version="$(arg UV_VERSION)"
[[ -n ${version} && -n ${uv_version} ]] || die "${spec} has no args.BASE_VERSION or args.UV_VERSION"

# notify2: desktop notifications over D-Bus, which the image doesn't have.
# --python-version: Debian trixie's python3, the image's. --python-platform:
# Linux only, without the Windows and macOS modules.
curl -fsSL "https://raw.githubusercontent.com/sabnzbd/sabnzbd/${version}/requirements.txt" |
    grep -v '^notify2' |
    docker run --rm -i "ghcr.io/astral-sh/uv:${uv_version}-trixie-slim" \
        uv pip compile --quiet --python-version 3.13 --python-platform linux \
        --generate-hashes --custom-compile-command "scripts/sabnzbd-lock.sh" - \
        >images/sabnzbd/requirements.lock
