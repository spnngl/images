#!/usr/bin/env bash
# Tests of discover.jq: which targets a change builds, and their
# SOURCE_DATE_EPOCH. Each case runs discover.jq on the fixtures below, as
# action.yml does, and checks one jq expression on its output.
#
# Usage: .github/actions/bake-discover/test.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v jq > /dev/null; then
  echo "jq is missing: brew install jq (macOS), or sudo apt-get install jq" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# `bake --print '*'`: two targets sharing a context, each with its
# <Containerfile>.dockerignore, as the bootc images; one alone in its
# folder, with a reports target without tags, as an application.
head='{
  "group": {
    "default": {"targets": ["fedora", "alma", "app", "app-reports"]},
    "vm-test": {"targets": ["fedora"]}
  },
  "target": {
    "fedora": {"context": "bootc", "dockerfile": "fedora/Containerfile", "tags": ["r/fedora:45"]},
    "alma": {"context": "bootc", "dockerfile": "alma/Containerfile", "tags": ["r/alma:10"], "args": {"SOURCE_DATE_EPOCH": "0"}},
    "app": {"context": "containers/app", "dockerfile": "Containerfile", "tags": ["r/app:1", "d/app:1"], "platforms": ["linux/amd64"]},
    "app-reports": {"context": "containers/app", "dockerfile": "Containerfile"}
  }
}'
# The .dockerignore lines of each target.
ign='{
  "fedora": ["*", "!fedora/sysroot", "!k3s/install.sh"],
  "alma": ["# comment", "*", "!alma", "alma/**/*.md"],
  "app": ["**/*.md", "!keep.md"],
  "app-reports": ["**/*.md", "!keep.md"]
}'
bakefiles='["docker-bake.hcl", "bootc/docker-bake.hcl", "bootc/fedora/docker-bake.hcl", "bootc/alma/docker-bake.hcl", "containers/app/docker-bake.hcl"]'
# `git log --format=@%ct --name-only --no-renames`, newest first.
log='@400
bootc/alma/docker-bake.hcl

@300
bootc/alma/x.sh

@200
bootc/fedora/docker-bake.hcl

@100
bootc/fedora/sysroot/etc/a
containers/app/main.go
'

# discover <changed> [sample] [base]: discover.jq's output. changed: the
# changed files, JSON, or null (no base); sample: JSON or null; base: the
# base's `bake --print`, the head's by default.
discover() {
  printf '%s' "${head}" > "${tmp}/head.json"
  printf '%s' "${3:-${head}}" > "${tmp}/base.json"
  printf '%s' "${log}" | jq -Rs -c -f .github/actions/bake-discover/discover.jq \
    --slurpfile head "${tmp}/head.json" \
    --slurpfile base "${tmp}/base.json" \
    --argjson ign "${ign}" \
    --argjson bakefiles "${bakefiles}" \
    --argjson changed "$1" \
    --argjson sample "${2:-null}" \
    --arg workflow build.yml \
    --arg headct 999
}

failed=0
# check <name> <jq expression> <discover's arguments...>
check() {
  local name="$1" expression="$2"
  shift 2
  if discover "$@" | jq -e "${expression}" > /dev/null; then
    echo "ok: ${name}"
  else
    echo "FAIL: ${name}: ${expression}, got:"
    discover "$@" | jq -c '{targets: [.targets[] | {id, epoch}], groups}'
    failed=1
  fi
}
# builds <ids...>: the expression "these targets, in any order".
builds() {
  printf '([.targets[].id] | sort) == (%s | sort)' "$(jq -cn '$ARGS.positional' --args "$@")"
}

check "a file its .dockerignore keeps" "$(builds fedora)" '["bootc/fedora/sysroot/etc/a"]'
check "a file kept by a negated rule, in another folder" "$(builds fedora)" '["bootc/k3s/install.sh"]'
check "files its .dockerignore drops" "$(builds)" '["bootc/fedora-coreos/x", "bootc/k3s/README.md", "README.md"]'
check "its Containerfile, which its .dockerignore drops" "$(builds fedora)" '["bootc/fedora/Containerfile"]'
check "its .dockerignore" "$(builds fedora)" '["bootc/fedora/Containerfile.dockerignore"]'
check "** matches across folders, the last rule decides" "$(builds)" '["bootc/alma/doc/x.md"]'
check "a file under a folder a negated rule keeps" "$(builds alma)" '["bootc/alma/doc/x.sh"]'
check "**/ also matches no folder" "$(builds)" '["containers/app/a.md"]'
check "a negated rule re-includes" "$(builds app)" '["containers/app/keep.md"]'
check "a target without tags is never built" "$(builds app)" '["containers/app/main.go"]'
check "a shared Bake file alone changes nothing" "$(builds)" '["bootc/docker-bake.hcl", "docker-bake.hcl"]'
check "a changed definition" "$(builds fedora)" '[]' null \
  "$(jq -c '.target.fedora.args = {"K": "1"}' <<< "${head}")"
check "a target the base lacks" "$(builds app)" '[]' null \
  "$(jq -c 'del(.target.app)' <<< "${head}")"
check "the workflow builds every target" "$(builds fedora alma app)" '[".github/workflows/build.yml"]'
check "an action builds every target" "$(builds fedora alma app)" '[".github/actions/bake-build/action.yml"]'
check "another workflow builds none" "$(builds)" '[".github/workflows/other.yml"]'
check "the workflow, with a sample: the sample and what changed" "$(builds app fedora)" \
  '[".github/workflows/build.yml", "bootc/fedora/sysroot/etc/a"]' '["app"]'
check "a sample alone builds nothing" "$(builds)" '[]' '["app"]'
check "no base builds every target, sample or not" "$(builds fedora alma app)" null '["app"]'
check "epoch: the last commit of the files it reads, or of its Bake file" \
  '[.targets[] | {(.id): .epoch}] | add == {"fedora": "200", "alma": "", "app": "100"}' null
check "platforms, repositories, one build per platform" \
  '(.targets[] | select(.id == "app") | .arches == ["amd64"] and .repositories == ["r/app", "d/app"])
   and (.builds.include | length) == 5' null
if discover '[]' '["app", "gone"]' > /dev/null 2>&1; then
  echo "FAIL: a sample name no target has fails discover"
  failed=1
else
  echo "ok: a sample name no target has fails discover"
fi
check "groups list their built targets only" '.groups == {"default": ["alma"], "vm-test": []}' '["bootc/alma/x.sh"]'

if ((failed)); then
  echo "discover.jq: some cases failed" >&2
  exit 1
fi
