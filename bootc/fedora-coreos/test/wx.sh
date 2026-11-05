# shellcheck shell=bash disable=SC2016
# test.sh sources this file. SC2016: the scripts passed to `bash -c` expand on
# the VM, not here.
# W^X (PLAN.md step 4): every writable mount is noexec, the exceptions are
# exec, and a binary copied to a writable place can't run.

# `findmnt` options of a mount point, empty when it isn't one.
opts() { findmnt --noheadings --output OPTIONS --mountpoint "$1"; }
export -f opts

for m in /var /etc /sysroot /sysroot/ostree/deploy/*/var /boot /boot/efi /tmp /dev/shm /run; do
    if findmnt --noheadings --mountpoint "${m}" >/dev/null; then
        check "${m} is nosuid,nodev,noexec" bash -c "
            o=\$(opts ${m})
            for f in nosuid nodev noexec; do [[ ,\${o}, == *,\${f},* ]] || { echo \"\${o}\"; exit 1; }; done"
    else
        echo "skip ${m} is not a mount point"
    fi
done
# The remount keeps them read-only (FCOS warns otherwise:
# coreos-warn-invalid-mounts).
for m in /sysroot /boot; do
    check "${m} is still ro" bash -c "o=\$(opts ${m}); [[ ,\${o}, == *,ro,* ]] || { echo \"\${o}\"; exit 1; }"
done
check "no invalid-mounts warning" test ! -e /run/motd.d/50_invalid_mounts.motd
for m in /var/lib/kubelet /var/opt/cni/bin; do
    check "${m} is exec" bash -c "o=\$(opts ${m}); [[ -n \${o} && ,\${o}, != *,noexec,* ]] || { echo \"\${o}\"; exit 1; }"
done

# A copy of /usr/bin/true can't run from the writable places, but can from /usr.
dirs="/var/tmp /etc /tmp /dev/shm /run"
for d in /sysroot/ostree/deploy/*/var/tmp; do dirs="${dirs} ${d}"; done
for d in ${dirs}; do
    check "a binary in ${d} can't run" bash -c "
        sudo cp /usr/bin/true ${d}/wx-test || exit 1
        # bash, not sudo, runs it: bash exits 126 when exec is refused, sudo
        # with 1 for any failure.
        rc=\$(sudo bash -c '${d}/wx-test 2>/dev/null; echo \$?')
        sudo rm -f ${d}/wx-test
        [[ \${rc} == 126 ]] || { echo \"exit \${rc}, not 126\"; exit 1; }"
done
check "binaries in /usr run" /usr/bin/true
check "a copy in /var/lib/kubelet runs" bash -c '
    sudo cp /usr/bin/true /var/lib/kubelet/wx-test && sudo /var/lib/kubelet/wx-test; rc=$?
    sudo rm -f /var/lib/kubelet/wx-test
    exit "${rc}"'
