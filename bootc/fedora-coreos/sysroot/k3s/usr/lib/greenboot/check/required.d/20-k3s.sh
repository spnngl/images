#!/bin/bash
# k3s' kubelet (in k3s.service or k3s-agent.service) must answer its health
# endpoint, once Ignition has enabled either unit: both ship disabled, and a
# node that runs neither has no kubelet to check.
#
# The checks aren't ordered after the units: k3s.service is Type=notify with
# no start timeout, and a server that never gets ready would hold greenboot,
# and its rollback, forever. This check waits for k3s instead, long enough for
# a server to bring its API, then its kubelet, up.
set -euo pipefail

systemctl is-enabled --quiet k3s.service k3s-agent.service || exit 0

# https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
# (--healthz-port, default 10248), which k3s leaves alone.
for _ in $(seq 300); do
    curl --silent --fail --max-time 2 http://127.0.0.1:10248/healthz >/dev/null && exit 0
    sleep 1
done
echo "k3s' kubelet doesn't answer on 127.0.0.1:10248/healthz after 300 s" >&2
exit 1
