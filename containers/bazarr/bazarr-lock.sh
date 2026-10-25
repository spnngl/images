#!/usr/bin/env bash
# Regenerate containers/bazarr/bazarr.lock: Bazarr's requirements.txt and
# postgres-requirements.txt at the BASE_VERSION of docker-bake.hcl, every
# module (sub-dependencies too) pinned to one version and to the hashes of
# its files on PyPI. The image build installs exactly these files (uv pip
# install --require-hashes), then checks that upstream's requirements
# files are still satisfied by them.
#
# Usage: containers/bazarr/bazarr-lock.sh    (after bumping BASE_VERSION or
#        UV_VERSION in containers/bazarr/docker-bake.hcl)
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
args="$(docker buildx bake -f containers/docker-bake.hcl -f containers/bazarr/docker-bake.hcl --print "*" 2>/dev/null | jq -c '.target[].args')"
version="$(jq -r .BASE_VERSION <<<"${args}")"
uv_version="$(jq -r .UV_VERSION <<<"${args}")"
[[ -n ${version} && -n ${uv_version} ]] || die "containers/bazarr/docker-bake.hcl has no BASE_VERSION or UV_VERSION"

# sed: uv rejects requirements.txt's `--only-binary=Pillow` after a
# requirement (it takes per-requirement options for hashes alone); the
# install passes --only-binary :all:, which covers it. The Containerfile's
# check strips it the same way. --python-version: Debian trixie's python3,
# the image's. --python-platform: Linux only, without the Windows modules.
for file in requirements.txt postgres-requirements.txt; do
    curl -fsSL "https://raw.githubusercontent.com/morpheus65535/bazarr/v${version}/${file}"
done |
    sed 's/ --only-binary=Pillow$//' |
    docker run --rm -i "ghcr.io/astral-sh/uv:${uv_version}-trixie-slim" \
        uv pip compile --quiet --python-version 3.13 --python-platform linux \
        --generate-hashes --custom-compile-command "containers/bazarr/bazarr-lock.sh" - \
        >containers/bazarr/bazarr.lock
