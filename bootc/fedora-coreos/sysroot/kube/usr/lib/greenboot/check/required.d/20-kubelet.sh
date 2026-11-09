#!/bin/bash
# kubelet must answer its health endpoint. A node that kubeadm hasn't joined
# yet has no kubelet.conf, and kubelet doesn't run: nothing to check.
set -euo pipefail

[[ -e /etc/kubernetes/kubelet.conf ]] || exit 0

# https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
# (--healthz-port, default 10248).
for _ in $(seq 120); do
    curl --silent --fail --max-time 2 http://127.0.0.1:10248/healthz >/dev/null && exit 0
    sleep 1
done
echo "kubelet doesn't answer on 127.0.0.1:10248/healthz after 120 s" >&2
exit 1
