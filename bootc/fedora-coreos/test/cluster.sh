# shellcheck shell=bash disable=SC2016
# test.sh sources this file. SC2016: the scripts passed to `bash -c` expand on
# the VM, not here.
# The node is Ready and a pod runs executables that come from pod volumes:
# the cases W^X (step 4) must keep working. emptyDir and configMap volumes
# both live under /var/lib/kubelet.

check "node is Ready" bash -c "k wait --for=condition=Ready node --all --timeout=60s"

k delete pod exec-test --ignore-not-found >/dev/null
k apply -f - >/dev/null <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: exec-test
data:
  run.sh: |
    #!/bin/sh
    echo configmap-ok
---
apiVersion: v1
kind: Pod
metadata:
  name: exec-test
spec:
  restartPolicy: Never
  containers:
    - name: test
      image: docker.io/library/busybox:1.37
      command:
        - sh
        - -c
        - |
          set -eu
          printf '#!/bin/sh\necho emptydir-ok\n' > /scratch/run.sh
          chmod +x /scratch/run.sh
          /scratch/run.sh
          /config/run.sh
      volumeMounts:
        - { name: scratch, mountPath: /scratch }
        - { name: config, mountPath: /config }
  volumes:
    - name: scratch
      emptyDir: {}
    - name: config
      configMap:
        name: exec-test
        defaultMode: 0755
YAML
check "pod runs scripts from an emptyDir and a configMap" bash -c '
    for _ in $(seq 120); do
        phase=$(sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get pod exec-test -o jsonpath={.status.phase})
        [[ ${phase} == Succeeded || ${phase} == Failed ]] && break
        sleep 2
    done
    out=$(sudo kubectl --kubeconfig /etc/kubernetes/admin.conf logs exec-test 2>&1)
    echo "${out}"
    [[ ${phase} == Succeeded ]] && grep -q emptydir-ok <<<"${out}" && grep -q configmap-ok <<<"${out}"'
k delete pod,configmap exec-test >/dev/null

# A control plane now: kubeadm wrote the etcd manifest.
check "etcd traffic gets the first band" bash -c '
    systemctl is-active --quiet etcd-network-tuning.service || exit 1
    for d in /sys/class/net/*/device; do
        n=$(basename "$(dirname "${d}")")
        tc qdisc show dev "${n}" | grep -q "^qdisc prio 1: root" || { echo "${n}: no prio"; exit 1; }
        tc filter show dev "${n}" | grep -q "match 094c0000/ffff0000" || { echo "${n}: no 2380 filter"; exit 1; }
    done'
# A new cluster has less than 100 MB to free: skipped_small, past the health
# check and the status read.
check "etcd-defrag runs on the member" bash -c '
    sudo systemctl start etcd-defrag.service &&
    sudo grep -qE "^etcd_defrag_result\{result=\"(defragmented|skipped_small)\"\} 1$" /var/lib/etcd-defrag/etcd-defrag.prom'
# Cilium's devices, netkit or veth.
check "networkd leaves Cilium's devices alone" bash -c '
    out=$(networkctl list --no-legend | awk "\$2 ~ /^(lxc|cilium_|veth)/ {print \$2, \$5}")
    [[ -n ${out} ]] || exit 1
    echo "${out}"; ! grep -v " unmanaged$" <<<"${out}"'
# ManageForeign*=no: a networkd restart keeps Cilium's routes.
check "Cilium's routes survive a networkd restart" bash -c '
    before=$(ip route show table all | grep -E "cilium_|lxc" | sort) && [[ -n ${before} ]] || exit 1
    sudo systemctl restart systemd-networkd && sleep 5
    diff <(echo "${before}") <(ip route show table all | grep -E "cilium_|lxc" | sort)'

check "no failed unit" bash -c '[[ -z $(systemctl --failed --no-legend) ]]'
