# shellcheck shell=bash disable=SC2016
# test.sh sources this file. SC2016: the scripts passed to `bash -c` expand on
# the VM, not here.
# Assertions on the booted node: kernel, live values, unit state. What holds
# for the image's files alone is checked at build time (test/build.yaml).

# The legacy x_tables tables can't load: iptables commands use nf_tables.
for m in ip_tables ip6_tables arp_tables ebtables; do
    check "module ${m} can't load" bash -c "! sudo modprobe ${m} 2>/dev/null && ! lsmod | grep -q ^${m}"
done
# usr/lib/bootc/kargs.d reached the disk (bootc, when osbuild deploys), once.
check "kernel arguments of kargs.d, once each" bash -c '
    for a in $(sudo bootc container inspect --json | jq -r ".kargs[]"); do
        [[ $(tr " " "\n" </proc/cmdline | grep -cxF -- "${a}") == 1 ]] || exit 1
    done'
check "kernel lockdown is integrity" grep -qF '[integrity]' /sys/kernel/security/lockdown
# modprobe.d/hardening.conf, a CIS level 2 module.
check "module squashfs can't load" bash -c '! sudo modprobe squashfs 2>/dev/null && ! lsmod | grep -q ^squashfs'
# etc/audit/rules.d: loaded and locked (-e 2), with the image's setuid
# programs, its backlog (kargs.d/20-audit.toml, 10-base.rules).
check "audit rules are loaded and locked" bash -c '
    s=$(sudo auditctl -s) &&
        grep -qx "enabled 2" <<<"${s}" && grep -qx "backlog_limit 8192" <<<"${s}" &&
        sudo auditctl -l | grep -q "path=/usr/bin/sudo .* -F key=privileged"'
# -c loads past a rule the kernel rejects, and -e 2 keeps it out until a
# reboot: every rule of augenrules' file must be in the kernel.
check "audit rules: the kernel has all of them" bash -c '
    [[ $(sudo grep -cE "^-[aw] " /etc/audit/audit.rules) == $(sudo auditctl -l | grep -cE "^-[aw] ") ]]'

# The rootless user (goss: user), made at boot by sysusers.d.
check "user rootless" bash -c '
    [[ $(getent passwd rootless) == rootless:x:1500:1500:*:/var/home/rootless:/bin/bash ]] &&
    id -nG rootless | grep -qw wheel'
check "rootless password is locked" bash -c '[[ $(sudo passwd -S rootless) == "rootless L"* ]]'
check "rootless home" bash -c '[[ $(stat -c %U:%a /var/home/rootless) == rootless:700 ]]'
# The initramfs no longer creates FCOS' core user (Containerfile, dracut).
check "no user core" bash -c '! getent passwd core && test ! -e /var/home/core'
check "SSH host keys are root:root 0600" bash -c '
    for k in /etc/ssh/ssh_host_*_key; do
        [[ $(sudo stat -c %U:%G:%a "${k}") == root:root:600 ]] || exit 1
    done'

# sshd's resolved config is checked at build time; here, what the running
# sshd does.
check "sshd ignores keys in /etc and ~/.ssh" bash -c '
    t=$(mktemp -d) && ssh-keygen -q -t ed25519 -N "" -f "${t}/key" || exit 1
    sudo install -D -m 0644 "${t}/key.pub" /etc/ssh/authorized_keys/rootless
    install -D -m 0600 "${t}/key.pub" ~/.ssh/authorized_keys.d/test
    install -D -m 0600 "${t}/key.pub" ~/.ssh/authorized_keys
    ssh -i "${t}/key" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR rootless@127.0.0.1 true && rc=0 || rc=$?
    sudo rm -f /etc/ssh/authorized_keys/rootless; rm -rf ~/.ssh/authorized_keys.d/test ~/.ssh/authorized_keys "${t}"
    # The directories install -D made, or the /etc drift scan reports them.
    sudo rmdir --ignore-fail-on-non-empty /etc/ssh/authorized_keys
    rmdir --ignore-fail-on-non-empty ~/.ssh/authorized_keys.d ~/.ssh
    [[ ${rc} == 255 ]]'

# containerd: its config is checked at build time; here, the running daemon.
check "containerd debug is a local socket" sudo test -S /run/containerd/debug.sock
# The first request of the pull goes to the first mirror.
check "docker.io pulls try the mirrors first" bash -c '
    sudo ctr image rm docker.io/library/busybox:1.37 >/dev/null 2>&1
    sudo ctr image pull --http-dump --hosts-dir /etc/containerd/certs.d docker.io/library/busybox:1.37 2>&1 |
        grep -a -m1 "Host: " | grep -q mirror.gcr.io'
check "crictl reaches containerd" sudo crictl info

# Units: their links and drop-ins are checked at build time; here, their
# state.
check "no failed unit" bash -c '[[ -z $(systemctl --failed --no-legend) ]]'
check "qemu-guest-agent runs on the VM" systemctl is-active qemu-guest-agent
check "etcd-network-tuning waits for the etcd manifest" bash -c '[[ $(systemctl show -P ActiveState etcd-network-tuning.service) == inactive ]] || test -e /etc/kubernetes/manifests/etcd.yaml'
# Profile `node`: what the build's scan can't check (systemd services) too.
check "openscap.service scans the node, no rule fails" bash -c '
    sudo systemctl start openscap.service &&
    ! sudo grep -E "<result>(fail|error)</result>" /var/lib/openscap/results.xml &&
    sudo grep -q "^openscap_rule{rule=" /var/lib/openscap/openscap.prom &&
    sudo grep -qx "audit_rules_rejected 0" /var/lib/openscap/openscap.prom'
check "etc-diff.service lists /etc's drift" bash -c '
    sudo systemctl start etc-diff.service &&
    sudo grep -q "^etc_diff_file{path=\"/etc/machine-id\",change=\"A\",expected=\"true\"" /var/lib/etc-diff/etc-diff.prom'
check "grype.service scans the node" bash -c '
    sudo systemctl start grype.service &&
    sudo grep -q "^grype_last_scan_timestamp_seconds " /var/lib/grype/grype.prom'
for u in auditd chronyd; do
    check "${u} is active" systemctl is-active "${u}"
done
check "conntrackd is not running" bash -c '! systemctl is-active conntrackd'
check "no swap" bash -c '[[ -z $(swapon --noheadings) ]]'
# systemd-networkd, not NetworkManager (capi-image-builder's systemd.yml).
for u in NetworkManager NetworkManager-wait-online NetworkManager-dispatcher; do
    check "${u} is masked" bash -c "[[ \$(systemctl is-enabled ${u}) == masked ]] && ! systemctl is-active ${u}"
done
check "systemd-networkd is active" systemctl is-active systemd-networkd
check "the VM NIC gets DHCP from 99-vm-dhcp.network" bash -c '
    dev=$(ip -4 route show default | awk "{print \$5; exit}") &&
    networkctl status --no-pager "${dev}" | grep -q "Network File: /usr/lib/systemd/network/99-vm-dhcp.network"'
# Cilium's links: netkit/veth pods (lxc*), cilium_*, and any veth.
for link in lxctest0 cilium_test vethtest0; do
    check "networkd leaves ${link} alone" bash -c "
        if [[ ${link} == veth* ]]; then sudo ip link add ${link} type veth peer name vethtest1; else sudo ip link add ${link} type dummy; fi || exit 1
        sudo ip link set ${link} up; sleep 2
        state=\$(networkctl list --no-legend ${link} | awk '{print \$5}')
        sudo ip link del ${link}
        [[ \${state} == unmanaged ]] || { echo \"\${state}\"; exit 1; }"
done
# node-local-dns' dummy link, as the pod creates it: networkd keeps the pod's
# address and points resolved at it for cluster names. On a cluster node, the
# pod's own link is checked, and left in place: deleting it would cut the
# node's cluster DNS.
check "nodelocaldns: DNS for svc.cluster.local, address kept" bash -c '
    made=false
    if ! ip link show nodelocaldns >/dev/null 2>&1; then
        sudo ip link add nodelocaldns type dummy && sudo ip addr add 169.254.25.10/32 dev nodelocaldns &&
            sudo ip link set nodelocaldns up && made=true || exit 1
        sleep 3
    fi
    s=$(resolvectl status nodelocaldns); a=$(ip -4 -o addr show dev nodelocaldns)
    if ${made}; then sudo ip link del nodelocaldns; fi
    grep -q "DNS Servers: 169.254.25.10" <<<"${s}" && grep -q "DNS Domain: ~svc.cluster.local" <<<"${s}" &&
        grep -q 169.254.25.10 <<<"${a}" || { echo "${s}"; echo "${a}"; exit 1; }'
# The live sources, not the file: on qemu, chronyd runs with FCOS' platform
# config, which must include ours too.
check "chrony uses our sources" bash -c 'sudo chronyc -N sources | grep -q time.cloudflare.com'
check "SELinux is permissive" bash -c '[[ $(getenforce) == Permissive ]]'

# sysctl and modules (goss: the /etc/sysctl.d files; here, live values).
while read -r key value; do
    check "sysctl ${key}" bash -c "[[ \$(sudo sysctl -n ${key}) == '${value}' ]]"
done <<'EOS'
net.ipv6.conf.all.disable_ipv6 1
net.ipv6.conf.default.disable_ipv6 1
net.core.default_qdisc fq
net.ipv4.tcp_congestion_control bbr
net.ipv4.tcp_slow_start_after_idle 0
fs.aio-max-nr 524288
fs.inotify.max_queued_events 1048576
fs.inotify.max_user_instances 1048576
fs.inotify.max_user_watches 1048576
net.core.bpf_jit_limit 1000000000
net.ipv4.neigh.default.gc_thresh1 1024
net.ipv4.neigh.default.gc_thresh2 28672
net.ipv4.neigh.default.gc_thresh3 32768
vm.max_map_count 1048576
net.ipv4.tcp_keepalive_time 60
kernel.softlockup_panic 0
kernel.panic 10
net.bridge.bridge-nf-call-iptables 1
net.bridge.bridge-nf-call-ip6tables 1
net.ipv4.ip_forward 1
vm.overcommit_memory 1
kernel.panic_on_oops 1
kernel.yama.ptrace_scope 1
kernel.dmesg_restrict 1
net.ipv4.conf.all.accept_redirects 0
net.ipv4.conf.all.log_martians 1
EOS
check "no link sends ICMP redirects" bash -c "! sudo sysctl -a 2>/dev/null | grep -E '^net\.ipv4\.conf\.[^.]+\.send_redirects = 1'"
# The softnet budget is for large machines with a Mellanox NIC: the test VM
# isn't one, the unit is condition-skipped there.
check "sysctl-mlx5-large skips the test VM" bash -c '[[ $(systemctl show -P ConditionResult sysctl-mlx5-large.service) == no ]]'
# The dedicated servers' sysctls: the test VM keeps the kernel default.
check "sysctl-metal skips the test VM" bash -c '[[ $(systemctl show -P ConditionResult sysctl-metal.service) == no ]]'
check "sysctl net.core.rmem_default" bash -c '[[ $(sudo sysctl -n net.core.rmem_default) == 212992 ]]'
for m in overlay br_netfilter; do
    check "module ${m} is loaded" bash -c "lsmod | grep -q ^${m}"
done
