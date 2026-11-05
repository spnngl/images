#!/usr/bin/env bash
# End to end test of the converter (PLAN.md step 6): the Ignition config that
# Cluster API renders for the first control plane machine, converted to spec
# 3.0, boots a test VM (vm.sh) that runs kubeadm init.
#
# Usage: bootc/fedora-coreos/ignition-converter/e2e.sh
# The input is testdata/kubeadm-init.json, with three changes for the VM: the
# Kubernetes version of the image, no /etc/hosts (the fixture's additional
# Container Linux Config replaces the VM's one), and CA and service account
# keys generated here in place of the fixture's placeholders (no key material
# in git: secret scanners flag it, throwaway or not).
# Env:   BUILD_KUBE_CONTEXT  kube context of the build cluster (required)
set -euo pipefail

cd "$(dirname "$0")/../../.."

for cmd in go jq openssl; do
    command -v "${cmd}" >/dev/null || { echo "error: ${cmd} is required" >&2; exit 1; }
done

version=$(sed -n 's/^ARG KUBERNETES_VERSION="\(.*\)"$/\1/p' bootc/fedora-coreos/Containerfile)
[[ -n ${version} ]] || { echo "error: no KUBERNETES_VERSION in the Containerfile" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

# kubeadm init needs each CA certificate with its key, and the service account
# key pair. kubeadm checks CA:TRUE, set explicitly: OpenSSL adds no extension
# without a config file. Written under ${tmp} at their path on the node.
pki=${tmp}/etc/kubernetes/pki
mkdir -p "${pki}/etcd"
ca() {
    openssl genpkey -quiet -algorithm RSA -out "${pki}/$1.key"
    openssl req -x509 -key "${pki}/$1.key" -days 3650 -subj "/CN=$2" \
        -addext basicConstraints=critical,CA:TRUE \
        -addext keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign \
        -out "${pki}/$1.crt"
}
ca ca kubernetes
ca etcd/ca etcd-ca
ca front-proxy-ca front-proxy-ca
openssl genpkey -quiet -algorithm RSA -out "${pki}/sa.key"
openssl pkey -in "${pki}/sa.key" -pubout -out "${pki}/sa.pub"
# {"/etc/kubernetes/pki/ca.crt": "data:,<URL-encoded PEM>", ...}
pki_sources=$(cd "${tmp}" && for f in etc/kubernetes/pki/*.* etc/kubernetes/pki/etcd/*; do
    jq -Rs --arg p "/${f}" '{($p): ("data:," + @uri)}' "${f}"
done | jq -s add)

# The URL-encoded kubeadm.yml holds the version. Both replacements fail loudly
# if the fixture changes under them, rather than boot the wrong config.
jq --arg v "${version}" --argjson pki "${pki_sources}" '
    def kubeadm_yml: .storage.files[] | select(.path == "/etc/kubeadm.yml").contents.source;
    if any(kubeadm_yml; test("v1\\.33\\.0")) then . else
        error("/etc/kubeadm.yml has no v1.33.0 to replace: update e2e.sh to the fixture") end
    | (kubeadm_yml) |= gsub("v1\\.33\\.0"; "v" + $v)
    | .storage.files |= map(select(.path != "/etc/hosts")
        | .contents.source = ($pki[.path] // .contents.source))
    | if any(.storage.files[].contents.source; contains("PLACEHOLDER")) then
        error("a fixture file is still a placeholder: generate it in e2e.sh") else . end' \
    bootc/fedora-coreos/ignition-converter/testdata/kubeadm-init.json >"${tmp}/init.json"
(cd bootc/fedora-coreos/ignition-converter && go run . --convert) <"${tmp}/init.json" >"${tmp}/init.ign"
jq -e '.ignition.version | startswith("3.")' "${tmp}/init.ign" >/dev/null

bootc/fedora-coreos/vm.sh up "${tmp}/init.ign"
# kubeadm.service (CABPK's) runs kubeadm init, then writes the file that
# Cluster API waits for.
for _ in $(seq 120); do
    if bootc/fedora-coreos/vm.sh ssh 'sudo test -e /run/cluster-api/bootstrap-success.complete'; then
        echo "ok: kubeadm init ran from the converted config"
        exit 0
    fi
    sleep 5
done
bootc/fedora-coreos/vm.sh ssh 'sudo journalctl -u kubeadm --no-pager | tail -n 40' || true
echo "error: /run/cluster-api/bootstrap-success.complete not written after 600 s" >&2
exit 1
