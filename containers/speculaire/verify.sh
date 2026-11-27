#!/usr/bin/env bash
# `speculaire verify` from the pushed list itself, on its digest, under
# policy.yaml (upstream D199): the gate a node runs on this image. As a
# node asks: anonymously (no registry login in the container), over the
# public-good TUF root. bake-push runs it once the list is signed and
# attested (.github/AGENTS.md, "Bake workflows").
#
# No runtime here: `--runtime containerd` and a containerd config
# without registry config send ghcr.io's requests to ghcr.io (upstream
# D17, D157). The container runs as the DaemonSet does (the
# Containerfile's header): no capability, a read-only root, a tmpfs for
# the TUF cache and the artifact store.
#
# Usage: containers/speculaire/verify.sh <repository>@<digest>
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

[[ $# -eq 1 && "$1" == *@sha256:* ]] || {
  echo "usage: containers/speculaire/verify.sh <repository>@<digest>" >&2
  exit 2
}
if ! command -v docker > /dev/null; then
  echo "docker is missing: https://docs.docker.com/engine/install/" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
printf 'version = 3\n' > "${tmp}/containerd.toml"
cat > "${tmp}/config.toml" << 'EOF'
[runtime]
containerd_config = "/etc/speculaire/containerd.toml"
[verify]
policy = "/etc/speculaire/policy.yaml"
tuf_cache = "/tmp/tuf"
EOF
cp containers/speculaire/policy.yaml "${tmp}/"
chmod -R a+rX "${tmp}"

docker run --rm --read-only --cap-drop ALL --security-opt no-new-privileges \
  --tmpfs /tmp -v "${tmp}:/etc/speculaire:ro" \
  "$1" verify --config /etc/speculaire/config.toml --runtime containerd "$1"
