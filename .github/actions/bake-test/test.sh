#!/usr/bin/env bash
# container-structure-test on one image, one platform: its kind's
# structure-test.yaml (<kind>/structure-test.yaml, what every image of
# the kind ships), then its own, beside its Containerfile or spec, when
# it has one (.github/REFERENCES.md, "Structure tests").
#
# Two ways to the image:
# - only metadata tests (labels, user, entrypoint...): the image's config
#   alone, read with skopeo, for the host driver (it reads a config file,
#   --metadata; inside its own container, it touches nothing else).
#   Nothing is copied: a bootc image is gigabytes.
# - else the Docker driver, on the image copied into Docker.
#
# Usage: .github/actions/bake-test/test.sh [--kind] <folder> <arch> <source>
#   --kind: the kind's file alone, the image's own left out: the
#           workflows' kind-test job, one runner for every platform,
#           reads each pushed image's config and never runs it.
#   folder: the image's, containers/<name> or bootc/<name>
#   arch:   amd64 or arm64, the platform of an image list to test
#   source: the image, as skopeo names it: oci:<dir> (an OCI layout,
#           bake-build's), oci-archive:<file>, docker-archive:<file>
#           (Bake's type=oci or type=docker with dest=<file>),
#           docker://<reference> (a registry, with Docker's login), or
#           docker-daemon:<reference> (an image of Docker, built with
#           `--set '*.output=type=docker'`)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

cst_image=ghcr.io/googlecontainertools/container-structure-test:1.22.1
skopeo_image=quay.io/skopeo/stable:v1.24.1

usage() {
  echo "usage: .github/actions/bake-test/test.sh [--kind] <folder> <arch> oci:<dir>|oci-archive:<file>|docker-archive:<file>|docker://<reference>|docker-daemon:<reference>" >&2
  exit 2
}

kind_only=0
if [[ "${1:-}" == --kind ]]; then
  kind_only=1
  shift
fi
[[ $# -eq 3 ]] || usage
folder="${1%/}"
arch="$2"
source="$3"
kind="${folder%%/*}"
[[ "${kind}" == containers || "${kind}" == bootc ]] || usage
[[ "${arch}" == amd64 || "${arch}" == arm64 ]] || usage
[[ -d "${folder}" ]] || {
  echo "${folder}: no such folder" >&2
  exit 2
}

if ! command -v docker > /dev/null; then
  echo "docker is missing: https://docs.docker.com/engine/install/" >&2
  exit 1
fi

# Whether a config has metadata tests alone: no top-level key but
# schemaVersion and metadataTest.
metadata_only() {
  local keys
  keys="$(grep -E '^[A-Za-z]+:' "$1" | cut -d: -f1)"
  ! grep -qvE '^(schemaVersion|metadataTest)$' <<< "${keys}"
}

configs=("${kind}/structure-test.yaml")
[[ -f "${configs[0]}" ]] || {
  echo "${configs[0]}: no such file" >&2
  exit 1
}
# The kind's tests run on every pushed image, without a build (the
# workflows' kind-test job): the image's config alone.
if ! metadata_only "${configs[0]}"; then
  echo "${configs[0]}: only schemaVersion and metadataTest: file and command tests go in an image's own structure-test.yaml" >&2
  exit 1
fi
if ((!kind_only)) && [[ -f "${folder}/structure-test.yaml" ]]; then
  configs+=("${folder}/structure-test.yaml")
fi
args=()
metadata=1
for c in "${configs[@]}"; do
  args+=(--config "/w/${c}")
  metadata_only "${c}" || metadata=0
done

tmp="$(mktemp -d)"
image=""
cleanup() {
  rm -rf "${tmp}"
  if [[ -n "${image}" ]]; then docker image rm --force "${image}" > /dev/null 2>&1 || true; fi
}
trap cleanup EXIT

# skopeo, from its image, with Docker's socket (docker-daemon:), the
# source's file or folder, and the ghcr.io login of Docker's config: a
# docker login writes it there, unless a credential store keeps it.
run=(--rm -v /var/run/docker.sock:/var/run/docker.sock)
auth="${DOCKER_CONFIG:-${HOME}/.docker}/config.json"
if [[ -f "${auth}" ]] && ! grep -qE '"(credsStore|credHelpers)"' "${auth}"; then
  run+=(-v "${auth}:/auth.json:ro" -e REGISTRY_AUTH_FILE=/auth.json)
fi
# The source as skopeo's container sees it.
case "${source}" in
  oci:* | oci-archive:* | docker-archive:*)
    path="${source#*:}"
    [[ -e "${path}" ]] || {
      echo "${path}: no such file or folder" >&2
      exit 2
    }
    path="$(cd "$(dirname "${path}")" && pwd)/$(basename "${path}")"
    run+=(-v "${path}:/source:ro")
    from="${source%%:*}:/source"
    ;;
  docker://* | docker-daemon:*) from="${source}" ;;
  *) usage ;;
esac
skopeo() {
  docker run "${run[@]}" "${skopeo_image}" "$@"
}

cst=(docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v "${PWD}:/w:ro" -v "${tmp}:/m:ro" "${cst_image}" test)

if ((metadata)); then
  # The image's config, as `skopeo inspect --config` gives it.
  case "${source}" in
    docker-daemon:*)
      docker image inspect --platform "linux/${arch}" --format '{"config": {{json .Config}}}' "${source#docker-daemon:}" > "${tmp}/config.json"
      ;;
    *)
      skopeo inspect --config --override-os linux --override-arch "${arch}" "${from}" > "${tmp}/config.json"
      ;;
  esac
  # --force: the host driver asks to confirm, as it would run on the
  # machine; it runs in its container, and reads the config alone.
  "${cst[@]}" --driver host --force --metadata /m/config.json "${args[@]}"
else
  case "${source}" in
    docker-daemon:*)
      ref="${source#docker-daemon:}"
      ;;
    *)
      ref="bake-test/${folder##*/}:${arch}-$$"
      skopeo copy --quiet --override-os linux --override-arch "${arch}" "${from}" "docker-daemon:${ref}"
      image="${ref}"
      ;;
  esac
  "${cst[@]}" --image "${ref}" --platform "linux/${arch}" "${args[@]}"
fi
