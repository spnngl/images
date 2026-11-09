#!/bin/bash
# From kubernetes-sigs/image-builder
# (ansible/roles/node/files/usr/local/bin/etcd-network-tuning.sh): put etcd's
# peer (2380) and client (2379) traffic on the high-priority band of a prio
# qdisc, on each physical NIC.
# Run by etcd-network-tuning.service, on control-plane nodes only: upstream's
# udev rule runs it on every node, and on a worker it would only replace the
# NIC's multi-queue qdisc with a single queue for nothing.
# Changed from upstream: each band gets fq, the default qdisc that BBR paces
# with (usr/lib/sysctl.d/996-bbr.conf), and it can run again (the root
# qdisc is deleted first; `tc qdisc add` fails on an existing one).
set -euo pipefail

for path in /sys/class/net/*/device; do
    dev=$(basename "$(dirname "${path}")")
    echo "Setting etcd network tuning on ${dev}"
    tc qdisc del dev "${dev}" root 2>/dev/null || true
    tc qdisc add dev "${dev}" root handle 1: prio bands 3
    for band in 1 2 3; do
        tc qdisc add dev "${dev}" parent "1:${band}" fq
    done
    tc filter add dev "${dev}" parent 1: protocol ip prio 1 u32 match ip sport 2380 0xffff flowid 1:1
    tc filter add dev "${dev}" parent 1: protocol ip prio 1 u32 match ip dport 2380 0xffff flowid 1:1
    tc filter add dev "${dev}" parent 1: protocol ip prio 2 u32 match ip sport 2379 0xffff flowid 1:1
    tc filter add dev "${dev}" parent 1: protocol ip prio 2 u32 match ip dport 2379 0xffff flowid 1:1
done
