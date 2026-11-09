# shellcheck shell=sh disable=SC3044
# From kubernetes-sigs/image-builder (ansible/roles/kubernetes/files/etc/profile.d/kubernetes.sh).
# Upstream tests `"x${PS1-}"`, which is always true; this tests that PS1 is set.

# Check for interactive bash
if [ -n "${BASH_VERSION-}" ] && [ -n "${PS1-}" ]; then
  ADMIN_CONF=/etc/kubernetes/admin.conf
  SUPER_ADMIN_CONF=/etc/kubernetes/super-admin.conf

  if [ -r "${SUPER_ADMIN_CONF}" ]; then
    export KUBECONFIG="${SUPER_ADMIN_CONF}"
  elif [ -r "${ADMIN_CONF}" ]; then
    export KUBECONFIG="${ADMIN_CONF}"
  fi

  alias k=kubectl
  __load_completion kubectl >/dev/null 2>&1 || true
  complete -F __start_kubectl k 2>/dev/null || true
fi
