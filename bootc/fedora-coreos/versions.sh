#!/usr/bin/env bash
# Print the image's versions, read from its Containerfile, as KEY=value
# lines: for `source <(...)` (build.sh) or "${GITHUB_ENV}" (build-bootc.yml).
#   BASE_VERSION, KUBERNETES_VERSION  the Containerfile's ARGs
#   IMAGE_TAG  <Fedora major>-v<Kubernetes minor>: a patch release reaches
#              the nodes with `bootc upgrade`, only a new tag needs
#              `bootc switch` (REFERENCES.md, "Tag").
set -euo pipefail

cd "$(dirname "$0")/../.."

containerfile=bootc/fedora-coreos/Containerfile
arg() {
    sed -n -E "s/^ARG $1=\"?([^\"[:space:]]+)\"?.*/\1/p" "${containerfile}"
}
base_version="$(arg BASE_VERSION)"
kubernetes_version="$(arg KUBERNETES_VERSION)"
if [[ ! ${base_version} =~ ^[0-9]+\. || ! ${kubernetes_version} =~ ^[0-9]+\.[0-9]+\. ]]; then
    echo "error: ${containerfile} needs ARG BASE_VERSION and ARG KUBERNETES_VERSION" >&2
    exit 1
fi

echo "BASE_VERSION=${base_version}"
echo "KUBERNETES_VERSION=${kubernetes_version}"
echo "IMAGE_TAG=${base_version%%.*}-v${kubernetes_version%.*}"
