#!/bin/bash
# containerd must be running: without it no pod starts, so the update is bad.
# Greenboot starts at multi-user.target, while containerd may still be coming
# up, hence the wait.
set -euo pipefail

for _ in $(seq 60); do
    systemctl is-active --quiet containerd.service && exit 0
    sleep 1
done
echo "containerd.service is not active after 60 s" >&2
exit 1
