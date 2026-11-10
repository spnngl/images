#!/usr/bin/env bash
# Test VM of bootc/fedora-coreos: boots the `qemu` disk image that build.sh
# made, inside the workbench (workbench.sh), with KVM.
#
# Usage: bootc/fedora-coreos/vm.sh up [ignition.ign]
#        bootc/fedora-coreos/vm.sh cluster
#        bootc/fedora-coreos/vm.sh ssh [command...]
#        bootc/fedora-coreos/vm.sh reboot
#        bootc/fedora-coreos/vm.sh log
#        bootc/fedora-coreos/vm.sh down
#   up    boot a fresh VM from the disk image (replaces a running one). The
#         optional Ignition config is merged into the one that gives the
#         `rootless` user a throwaway SSH key.
#   cluster  run kubeadm init in the VM, then install Cilium from the
#         workbench, through the forwarded API port
#   ssh   run a command on the VM, or a script read from stdin
#         when there is no command
#   reboot  reboot the VM, wait until it answers over SSH again
#   log   print the VM's serial console
#   down  stop the VM and delete its disk
# Env:    WORKBENCH, BUILD_KUBE_CONTEXT  the workbench (workbench.sh)
# In the workbench, the VM answers on 127.0.0.1: SSH on 2222, the Kubernetes
# API on 6443. Files are in /work/vm. Its disk is NVMe, as on the dedicated
# servers.
set -euo pipefail

cd "$(dirname "$0")/../.."

die() {
    echo "error: $*" >&2
    exit 1
}

workbench=bootc/fedora-coreos/workbench.sh
# Itself, from the repository root (cd above): $0 may be relative.
self=bootc/fedora-coreos/vm.sh

up() {
    local config="${1:-}"
    if [[ -n ${config} ]]; then
        [[ -f ${config} ]] || die "${config} not found"
        "${workbench}" exec bash -c 'mkdir -p /work/vm && cat > /work/vm/extra.ign' <"${config}"
    else
        "${workbench}" exec bash -c 'mkdir -p /work/vm && rm -f /work/vm/extra.ign' </dev/null
    fi
    # A quoted heredoc: everything below runs in the workbench.
    "${workbench}" exec <<'EOF'
set -euo pipefail
cd /work/vm

disk=/work/fedora-coreos-qemu.x86_64.qcow2
[[ -f ${disk} ]] || { echo "error: ${disk} not found, run: bootc/fedora-coreos/build.sh qemu" >&2; exit 1; }

# Only one VM: replace the running one.
pid=$(cat qemu.pid 2>/dev/null || true)
if [[ -n ${pid} ]] && kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}"
    while kill -0 "${pid}" 2>/dev/null; do sleep 1; done
fi

[[ -f key ]] || ssh-keygen -q -t ed25519 -N '' -C vm-test -f key

# sshd reads keys from the image only (etc/ssh/sshd_config.d/00-hardening.conf):
# the test key gets its own directory, through a drop-in that sorts before
# 00-hardening.conf (sshd keeps the first AuthorizedKeysFile). Not
# /etc/ssh/authorized_keys: test/system/node.yaml checks that sshd ignores
# it. The drop-in is 0600, as OpenSCAP's file_permissions_sshd_drop_in_config
# wants: test.sh node fails on any failed rule.
{
    cat <<BU
variant: fcos
version: 1.5.0
BU
    if [[ -f extra.ign ]]; then
        cat <<BU
ignition:
  config:
    merge:
      - local: extra.ign
BU
    fi
    cat <<BU
storage:
  files:
    - path: /etc/ssh/sshd_config.d/0-vm-test.conf
      mode: 0600
      contents:
        inline: |
          AuthorizedKeysFile /usr/lib/ssh/authorized_keys/%u /etc/ssh/vm-test-keys/%u
    - path: /etc/ssh/vm-test-keys/rootless
      mode: 0644
      contents:
        inline: |
          $(cat key.pub)
BU
} > config.bu
butane --strict --files-dir /work/vm config.bu > config.ign

# A copy-on-write overlay, bigger than the image: the root filesystem grows
# on first boot.
rm -f overlay.qcow2
qemu-img create -q -f qcow2 -b "${disk}" -F qcow2 overlay.qcow2 40G
cp /usr/share/edk2/ovmf/OVMF_VARS.fd OVMF_VARS.fd
: > console.log

# The guest agent's channel, as OpenStack's hw_qemu_guest_agent gives it.
qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 4 -m 8192 \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file=OVMF_VARS.fd \
    -drive if=none,id=disk0,file=overlay.qcow2,format=qcow2 \
    -device nvme,serial=os,drive=disk0,bootindex=0 \
    -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:6443-:6443 \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-rng-pci \
    -device virtio-serial -chardev socket,id=qga0,path=qga.sock,server=on,wait=off \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    -fw_cfg name=opt/com.coreos/config,file=config.ign \
    -display none -serial file:console.log \
    -daemonize -pidfile qemu.pid

for _ in $(seq 300); do
    if ssh -i key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=3 -o BatchMode=yes rootless@127.0.0.1 true 2>/dev/null; then
        echo "VM is up"
        exit 0
    fi
    sleep 1
done
echo "error: no SSH after 300 s, console:" >&2
tail -n 60 console.log >&2
exit 1
EOF
}

cluster() {
    "${workbench}" exec <<'EOF'
set -euo pipefail
cd /work/vm
ssh_vm() {
    ssh -i key -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o BatchMode=yes rootless@127.0.0.1 "$@" </dev/null
}

# The pod CIDR is Cilium's (cluster-pool IPAM). No kube-proxy: Cilium
# replaces it. NumCPU and Mem: the VM is small.
ssh_vm "sudo kubeadm init --kubernetes-version \"\$(kubeadm version -o short)\" \
    --pod-network-cidr 10.244.0.0/16 --skip-phases=addon/kube-proxy \
    --ignore-preflight-errors=NumCPU,Mem" | tail -n 5

# The workbench reaches the API through the forwarded port; the certificate
# is for the name `kubernetes`, not 127.0.0.1.
ssh_vm sudo cat /etc/kubernetes/admin.conf > admin.conf
sed -i -e 's|server: .*|server: https://127.0.0.1:6443|' -e '/server: https/a\    tls-server-name: kubernetes' admin.conf
export KUBECONFIG=/work/vm/admin.conf

# 1.20+: older Cilium releases fail on the BPF verifier of kernel 7.x
# ("failed to probe helper ... call bpf_set_retval#187: R1 is not a scalar").
helm repo add cilium https://helm.cilium.io >/dev/null
helm upgrade --install cilium cilium/cilium --version 1.20.4 -n kube-system \
    --set k8sServiceHost=10.0.2.15 --set k8sServicePort=6443 \
    --set kubeProxyReplacement=true --set ipam.mode=cluster-pool \
    --set operator.replicas=1 --wait --timeout 8m >/dev/null

# One node: the control plane runs the pods of the tests.
ssh_vm sudo kubectl --kubeconfig /etc/kubernetes/admin.conf taint nodes --all node-role.kubernetes.io/control-plane-
ssh_vm sudo kubectl --kubeconfig /etc/kubernetes/admin.conf wait --for=condition=Ready node --all --timeout=300s
EOF
}

case "${1:-}" in
cluster) cluster ;;
up)
    shift
    up "$@"
    ;;
ssh)
    shift
    # Timeouts: QEMU's port forward accepts the connection even while the
    # VM reboots, and a session the reboot cuts never closes. Without
    # them, a wait for the VM (reboot, test-greenboot.sh) can hang.
    "${workbench}" exec ssh -i /work/vm/key -p 2222 -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes \
        -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=6 \
        rootless@127.0.0.1 "$@"
    ;;
reboot)
    # The SSH session dies with the VM: its exit status says nothing.
    "${self}" ssh 'sudo systemctl reboot' || true
    sleep 20
    for _ in $(seq 120); do
        if "${self}" ssh true 2>/dev/null; then
            exit 0
        fi
        sleep 5
    done
    die "the VM didn't come back; console:" "$("${self}" log | tail -n 40)"
    ;;
log) "${workbench}" exec cat /work/vm/console.log ;;
down)
    # Single quotes: it runs in the workbench.
    # shellcheck disable=SC2016
    "${workbench}" exec bash -c '
        if [[ -f /work/vm/qemu.pid ]]; then kill "$(cat /work/vm/qemu.pid)" 2>/dev/null || true; fi
        rm -rf /work/vm'
    ;;
*) die "usage: $0 up [ignition.ign]|cluster|ssh [command...]|reboot|log|down" ;;
esac
