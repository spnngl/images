#!/bin/bash
# The driver must see a GPU: without one no GPU pod runs, so the update is
# bad. Greenboot starts at multi-user.target, while the modules may still be
# loading, hence the wait.
set -euo pipefail

for _ in $(seq 60); do
    nvidia-smi --list-gpus 2>/dev/null | grep -q '^GPU ' && exit 0
    sleep 1
done
echo "nvidia-smi lists no GPU after 60 s" >&2
exit 1
