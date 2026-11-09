#!/usr/bin/env bash
# Greenboot on the test VM (vm.sh up): an update that boots is kept, and
# one that fails a required check is rolled back.
#
# Usage: bootc/fedora-coreos/test-greenboot.sh
# It needs the archive that build.sh made (/work/fedora-coreos.ociarchive in
# the workbench). Both updates are that image plus one layer, built in the
# workbench, copied into the VM and applied with `bootc switch`:
#   good  adds a marker file
#   bad   adds a required check that fails
# Env:    WORKBENCH, BUILD_KUBE_CONTEXT  the workbench (workbench.sh)
set -euo pipefail

cd "$(dirname "$0")/../.."

workbench=bootc/fedora-coreos/workbench.sh
vm=bootc/fedora-coreos/vm.sh

die() {
    echo "error: $*" >&2
    exit 1
}

# The image that the VM booted, from `bootc status`.
booted() { "${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.image.image'; }

step() { echo "== $*"; }

step "build the two updates in the workbench"
"${workbench}" exec <<'EOF'
set -euo pipefail
cd /work/vm
# An empty build context: /work/vm holds the VM's disks, which podman would
# copy for nothing.
ctx=$(mktemp -d)
for variant in good bad; do
    case "${variant}" in
    good) run="touch /usr/share/greenboot-test-good" ;;
    bad) run="printf '#!/bin/bash\nexit 1\n' > /usr/lib/greenboot/check/required.d/99-fail.sh && chmod +x /usr/lib/greenboot/check/required.d/99-fail.sh" ;;
    esac
    printf 'FROM oci-archive:/work/fedora-coreos.ociarchive\nRUN %s\n' "${run}" > "${ctx}/Containerfile.${variant}"
    podman build -q -f "${ctx}/Containerfile.${variant}" -t "localhost/update-${variant}" "${ctx}"
    rm -f "${variant}.ociarchive"
    podman save --format oci-archive -o "${variant}.ociarchive" "localhost/update-${variant}" 2>/dev/null
    scp -q -i key -P 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        "${variant}.ociarchive" rootless@127.0.0.1:/var/tmp/
    rm -f "${variant}.ociarchive"
done
rm -rf "${ctx}"
EOF

step "before: greenboot passed on this boot"
"${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
before=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')

step "good update: boots, and greenboot marks it successful"
"${vm}" ssh 'sudo bootc switch --transport oci-archive /var/tmp/good.ociarchive'
"${vm}" reboot
"${vm}" ssh 'test -e /usr/share/greenboot-test-good'
sleep 30
"${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
good=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')
[[ ${good} != "${before}" ]] || die "the VM booted the same image after the good update"

step "bad update: greenboot reboots GREENBOOT_MAX_BOOT_ATTEMPTS times, then rolls back"
"${vm}" ssh 'sudo bootc switch --transport oci-archive /var/tmp/bad.ociarchive'
"${vm}" reboot
# The failing boots reboot the VM by themselves; wait for the one that stays.
for _ in $(seq 60); do
    sleep 10
    if "${vm}" ssh '! test -e /usr/lib/greenboot/check/required.d/99-fail.sh' 2>/dev/null; then
        break
    fi
done
sleep 30
now=$("${vm}" ssh 'sudo bootc status --json' | jq -r '.status.booted.image.imageDigest')
[[ ${now} == "${good}" ]] || die "expected to be back on the good image (${good}), booted ${now}"
"${vm}" ssh 'sudo grub2-editenv list | grep -x boot_success=1'
"${vm}" ssh 'sudo journalctl --no-pager -u greenboot-healthcheck -u greenboot-set-rollback-trigger | tail -n 30'
echo "ok: the good update is kept ($(booted)), the bad one is rolled back"
