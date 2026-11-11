#!/usr/bin/env bash
# Checks one kind of image's sources against the policies of policy/
# (policy/AGENTS.md): `conftest verify`, then one `conftest test` per
# namespace, every file of that namespace's input at once. A namespace's
# failures don't stop the next; the script exits 1 if any failed.
#
# Usage: policy/conftest.sh [--sarif <dir>] containers|bootc
#   --sarif <dir>: also write <dir>/<namespace>.sarif, for code scanning.
set -euo pipefail
shopt -s failglob
cd "$(dirname "${BASH_SOURCE[0]}")/.."

conftest_image=docker.io/openpolicyagent/conftest:v0.71.1

usage() {
  echo "usage: policy/conftest.sh [--sarif <dir>] containers|bootc" >&2
  exit 2
}

sarif=""
if [[ "${1:-}" == --sarif ]]; then
  [[ $# -ge 2 ]] || usage
  sarif="$2"
  shift 2
fi
[[ $# -eq 1 ]] || usage
kind="$1"
[[ "${kind}" == containers || "${kind}" == bootc ]] || usage

if ! command -v docker > /dev/null; then
  echo "docker is missing: https://docs.docker.com/engine/install/" >&2
  exit 1
fi
if ! docker buildx version > /dev/null 2>&1; then
  echo "docker buildx is missing: https://docs.docker.com/build/concepts/overview/#install-buildx" >&2
  exit 1
fi
if [[ "${kind}" == bootc ]] && ! command -v git > /dev/null; then
  echo "git is missing: brew install git (macOS), or sudo apt-get install git" >&2
  exit 1
fi
if [[ -n "${sarif}" ]] && ! command -v jq > /dev/null; then
  echo "jq is missing: brew install jq (macOS), or sudo apt-get install jq" >&2
  exit 1
fi
[[ -z "${sarif}" ]] || mkdir -p "${sarif}"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# The resolved definition (matrix and functions applied, as CI builds
# it), not the HCL: the bake namespaces check what Bake makes of it.
f=(-f docker-bake.hcl -f "${kind}/docker-bake.hcl")
for x in "${kind}"/*/docker-bake.hcl; do f+=(-f "${x}"); done
docker buildx bake "${f[@]}" --progress quiet --print '*' > "${tmp}/bake.json"

conftest() {
  docker run --rm -v "${PWD}:/w:ro" -v "${tmp}:/bake:ro" -w /w "${conftest_image}" "$@"
}

failed=0

echo "== verify"
conftest verify --no-color --policy policy || failed=1

# check <namespace> <conftest test arguments>
check() {
  local ns="$1"
  shift
  echo "== ${ns}"
  conftest test --no-color --policy policy --namespace "${ns}" "$@" || failed=1
  [[ -n "${sarif}" ]] || return 0
  # Code scanning places an alert in a file of the repository: the
  # definition's is the kind's Bake file, where tags() is. One category
  # per namespace (automationDetails.id), stable so fixed findings close.
  # --combine's location is "Combined": the first file passed, whose
  # path each message names anyway. conftest also reports each passing
  # file (level none): left out, as hadolint does.
  conftest test --policy policy --namespace "${ns}" --output sarif "$@" \
    | jq --arg bake "${kind}/docker-bake.hcl" --arg first "${2:-}" \
      --arg id "conftest-${ns}/" \
      '(.. | .uri? | select(. == "/bake/bake.json")) |= $bake
      | (.. | .uri? | select(. == "Combined")) |= $first
      | .runs[].results |= map(select(.level != "none"))
      | .runs[].automationDetails.id = $id' \
      > "${sarif}/${ns}.sarif" || true
}

case "${kind}" in
  containers)
    check containers.containerfile --parser dockerfile containers/*/Containerfile
    check containers.dalec containers/*/spec.yml
    check containers.bake /bake/bake.json
    ;;
  bootc)
    check bootc.containerfile --parser dockerfile bootc/*/Containerfile
    check bootc.bake /bake/bake.json
    check bootc.signature --combine \
      bootc/*/sysroot/*/etc/containers/policy.json \
      bootc/*/sysroot/*/etc/containers/registries.d/*.yaml
    # The units, drop-ins and .network files of fedora-coreos's platform
    # layers; the *.wants/ links only enable them.
    units=()
    while IFS= read -r u; do
      [[ "${u}" == */*.wants/* ]] || units+=("${u}")
    done < <(git ls-files \
      'bootc/fedora-coreos/sysroot/vm/usr/lib/systemd/*' \
      'bootc/fedora-coreos/sysroot/metal/usr/lib/systemd/*')
    check bootc.units --parser ini "${units[@]}"
    ;;
esac

exit "${failed}"
