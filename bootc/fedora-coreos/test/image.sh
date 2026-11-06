# shellcheck shell=bash disable=SC2016
# test.sh sources this file. SC2016: the scripts passed to `bash -c` expand on
# the VM, not here.
# Assertions on what the image ships. Unlike capi-image-builder's goss (which
# can only check files, the build VM is not rebooted), these run on a booted
# node, so sysctl and unit state are asserted as live values.

# Packages (goss: package).
for p in kubelet kubeadm kubectl cri-tools containerd runc conntrack-tools \
    socat sysstat iproute-tc rootlesskit net-tools qemu-guest-agent \
    systemd-udev systemd-networkd openssh-clients grype nushell bootc rpm-ostree podman; do
    check "package ${p}" rpm -q "${p}"
done
for p in zincati moby-engine docker-cli toolbox firewalld ufw iptables-legacy iptables-services \
    nmstate NetworkManager-team NetworkManager-tui NetworkManager-cloud-setup ModemManager \
    etcd dnsmasq rsync rpcbind nfsv3-client-utils; do
    check "package ${p} is absent" bash -c "! rpm -q ${p}"
done
# iptables commands use nf_tables; the legacy x_tables tables can't load.
check "signatures: our images use sigstore attachments" grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/spnngl-images.yaml
check "signatures: the key policy.json names" bash -c 'test -s "$(jq -r '\''.transports.docker["ghcr.io/spnngl/images"][0].keyPath'\'' /etc/containers/policy.json)"'
check "iptables is iptables-nft" bash -c 'iptables --version | grep -q nf_tables'
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

# The rootless user (goss: user, visudo-usable).
check "user rootless" bash -c '
    [[ $(getent passwd rootless) == rootless:x:1500:1500:*:/var/home/rootless:/bin/bash ]] &&
    id -nG rootless | grep -qw wheel'
check "rootless password is locked" bash -c '[[ $(sudo passwd -S rootless) == "rootless L"* ]]'
check "rootless sudoers" bash -c '
    [[ $(sudo stat -c %a /etc/sudoers.d/99-rootless) == 440 ]] &&
    sudo visudo -cf /etc/sudoers.d/99-rootless'
check "rootless home" bash -c '[[ $(stat -c %U:%a /var/home/rootless) == rootless:700 ]]'
check "rootless keys" bash -c '[[ $(grep -c ^ssh-ed25519 /usr/lib/ssh/authorized_keys/rootless) == 8 ]]'
# The initramfs no longer creates FCOS' core user (Containerfile, dracut).
check "no user core" bash -c '! getent passwd core && test ! -e /var/home/core'
# sshd-keygen@.service.d/50-ssh-keys-group.conf
check "SSH host keys are root:ssh_keys 0600" bash -c '
    for k in /etc/ssh/ssh_host_*_key; do
        [[ $(sudo stat -c %U:%G:%a "${k}") == root:ssh_keys:600 ]] || exit 1
    done'

# sshd (goss: sshd-effective-config; the pubkey login is how this script
# got in). A throwaway host key: `sshd -T` refuses to run without one. -C:
# what applies to rootless, Match blocks included.
sshd_config=$(
    k=$(mktemp -u) && ssh-keygen -q -t ed25519 -N '' -f "${k}" &&
        sudo sshd -T -h "${k}" -C user=rootless,host=x,addr=192.0.2.1
    rm -f "${k}" "${k}.pub"
)
for line in "passwordauthentication no" "permitrootlogin no" "usepam yes" \
    "kbdinteractiveauthentication no" "authenticationmethods publickey" \
    "allowusers rootless" "maxauthtries 3" "allowagentforwarding no" \
    "allowtcpforwarding local" "gatewayports no" "gssapiauthentication no"; do
    check "sshd: ${line}" bash -c "grep -qxF '${line}' <<<'${sshd_config}'"
done
# The image's value; vm.sh adds the test key's directory before it, through
# Ignition. The Containerfile checks the image's resolved value.
check "sshd: keys only from /usr" sudo grep -qx 'AuthorizedKeysFile /usr/lib/ssh/authorized_keys/%u' /etc/ssh/sshd_config.d/00-hardening.conf
check "sshd ignores keys in /etc and ~/.ssh" bash -c '
    t=$(mktemp -d) && ssh-keygen -q -t ed25519 -N "" -f "${t}/key" || exit 1
    sudo install -D -m 0644 "${t}/key.pub" /etc/ssh/authorized_keys/rootless
    install -D -m 0600 "${t}/key.pub" ~/.ssh/authorized_keys.d/test
    install -D -m 0600 "${t}/key.pub" ~/.ssh/authorized_keys
    ssh -i "${t}/key" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR rootless@127.0.0.1 true && rc=0 || rc=$?
    sudo rm -f /etc/ssh/authorized_keys/rootless; rm -rf ~/.ssh/authorized_keys.d/test ~/.ssh/authorized_keys "${t}"
    [[ ${rc} == 255 ]]'

# containerd (goss: containerd-merged-config, cri-base-json-*, pause-*).
check "containerd runs our config" bash -c 'systemctl show -p ExecStart containerd | grep -qF /usr/lib/containerd/config.toml'
config=$(containerd --config /usr/lib/containerd/config.toml config dump 2>&1)
for text in "SystemdCgroup = true" "/usr/lib/containerd/cri-base.json" "use_internal_loopback = true" \
    "/opt/cni/bin" "max_container_log_line_size = 16384" "enable_selinux = false"; do
    check "containerd config: ${text}" bash -c "grep -qF '${text}' <<<'${config}'"
done
check "cri-base.json equals ctr oci spec but for rlimits" bash -c '
    jq -S "del(.ociVersion, .process.rlimits)" /usr/lib/containerd/cri-base.json >/tmp/ours &&
    ctr oci spec | jq -S "del(.ociVersion, .process.rlimits)" >/tmp/default &&
    diff /tmp/default /tmp/ours &&
    jq -e ".process.rlimits == [{type:\"RLIMIT_NOFILE\",hard:65535,soft:65535}]" /usr/lib/containerd/cri-base.json'
check "pause image is kubeadm's, in the merged config" bash -c '
    want=$(kubeadm config images list --kubernetes-version "v$(rpm -q --qf "%{VERSION}" kubeadm)" | grep /pause:) &&
    grep -qF "sandbox = '\''${want}'\''" <<<"$(containerd --config /usr/lib/containerd/config.toml config dump)"'
check "containerd debug is a local socket" sudo test -S /run/containerd/debug.sock
# The first request of the pull goes to the first mirror.
check "docker.io pulls try the mirrors first" bash -c '
    sudo ctr image rm docker.io/library/busybox:1.37 >/dev/null 2>&1
    sudo ctr image pull --http-dump --hosts-dir /etc/containerd/certs.d docker.io/library/busybox:1.37 2>&1 |
        grep -a -m1 "Host: " | grep -q mirror.gcr.io'
check "bash completion for kubectl, kubeadm, crictl" bash -c '
    for t in kubectl kubeadm crictl; do [[ -s /usr/share/bash-completion/completions/${t} ]] || { echo "missing: ${t}"; exit 1; }; done'
check "crictl reaches containerd" sudo crictl info

# Units (goss: systemd-coredump-socket-not-masked, amd-hsmp-unit-enabled).
check "no failed unit" bash -c '[[ -z $(systemctl --failed --no-legend) ]]'
# Enabled by links in /usr/lib (Containerfile): systemd reports the target that
# pulls each one in, whatever `is-enabled` calls the link.
for u in containerd.service kubelet.service amd-hsmp.service \
    openstack-hostname.service openstack-disk-tags.service greenboot-healthcheck.service \
    systemd-networkd.service; do
    check "${u} is wanted by multi-user.target" bash -c "systemctl show -P WantedBy ${u} | grep -qw multi-user.target"
done
# What systemd-detect-virt says: VM-only units, bare-metal-only ones.
for u in openstack-hostname openstack-disk-tags qemu-guest-agent; do
    check "${u} is for VMs only" bash -c "systemctl cat ${u} | grep -qx ConditionVirtualization=vm"
done
check "amd-hsmp is for bare metal only" bash -c "systemctl cat amd-hsmp | grep -qx ConditionVirtualization=false"
check "qemu-guest-agent runs on the VM" systemctl is-active qemu-guest-agent
check "etcd-network-tuning.path is wanted by paths.target" bash -c "systemctl show -P WantedBy etcd-network-tuning.path | grep -qw paths.target"
check "etcd-network-tuning waits for the etcd manifest" bash -c '[[ $(systemctl show -P ActiveState etcd-network-tuning.service) == inactive ]] || test -e /etc/kubernetes/manifests/etcd.yaml'
check "etcd-defrag.timer is wanted by timers.target" bash -c "systemctl show -P WantedBy etcd-defrag.timer | grep -qw timers.target"
check "etcd-defrag waits for the etcd manifest" bash -c 'systemctl cat etcd-defrag.service | grep -qx ConditionPathExists=/etc/kubernetes/manifests/etcd.yaml'
check "openscap.timer is wanted by timers.target" bash -c "systemctl show -P WantedBy openscap.timer | grep -qw timers.target"
# Profile `node`: what the build's scan can't check (systemd services) too.
check "openscap.service scans the node, no rule fails" bash -c '
    sudo systemctl start openscap.service &&
    ! sudo grep -E "<result>(fail|error)</result>" /var/lib/openscap/results.xml &&
    sudo grep -q "^openscap_rule{rule=" /var/lib/openscap/openscap.prom &&
    sudo grep -qx "audit_rules_rejected 0" /var/lib/openscap/openscap.prom'
check "etc-diff.timer is wanted by timers.target" bash -c "systemctl show -P WantedBy etc-diff.timer | grep -qw timers.target"
check "etc-diff.service lists /etc's drift" bash -c '
    sudo systemctl start etc-diff.service &&
    sudo grep -q "^etc_diff_file{path=\"/etc/machine-id\",change=\"A\",expected=\"true\"" /var/lib/etc-diff/etc-diff.prom'
check "grype.timer is wanted by timers.target" bash -c "systemctl show -P WantedBy grype.timer | grep -qw timers.target"
check "grype.service scans the node" bash -c '
    sudo systemctl start grype.service &&
    sudo grep -q "^grype_last_scan_timestamp_seconds " /var/lib/grype/grype.prom'
check "rpm-ostree-countme.timer is masked" bash -c '[[ $(systemctl is-enabled rpm-ostree-countme.timer) == masked ]]'
for u in auditd chronyd; do
    check "${u} is active" systemctl is-active "${u}"
done
check "conntrackd is not running" bash -c '! systemctl is-active conntrackd'
check "no swap" bash -c '[[ -z $(swapon --noheadings) ]]'
check "wx-remount.service is wanted by sysinit.target" bash -c "systemctl show -P WantedBy wx-remount.service | grep -qw sysinit.target"
for u in var-lib-kubelet.mount var-opt-cni-bin.mount; do
    check "${u} is wanted by local-fs.target" bash -c "systemctl show -P WantedBy ${u} | grep -qw local-fs.target"
done
check "greenboot rollback trigger is required by ostree-finalize-staged" bash -c "systemctl show -P RequiredBy greenboot-set-rollback-trigger.service | grep -qw ostree-finalize-staged.service"
check "systemd-coredump.socket is not masked" bash -c '[[ $(systemctl is-enabled systemd-coredump.socket) != masked* ]]'
check "zincati and docker are gone" bash -c '! systemctl cat zincati docker.socket'
for u in containerd kubelet; do
    check "${u} is in kube.slice" bash -c "[[ \$(systemctl show -p Slice ${u}) == Slice=kube.slice ]]"
done
check "coredump storage" bash -c 'systemd-analyze cat-config systemd/coredump.conf | grep -qx Storage=external'
check "resolved settings" bash -c '
    systemd-analyze cat-config systemd/resolved.conf | grep -qx "Domains=~." &&
    systemd-analyze cat-config systemd/resolved.conf | grep -q "^FallbackDNS=1.1.1.1#cloudflare-dns.com"'
# systemd-networkd, not NetworkManager (capi-image-builder's systemd.yml).
for u in NetworkManager NetworkManager-wait-online NetworkManager-dispatcher; do
    check "${u} is masked" bash -c "[[ \$(systemctl is-enabled ${u}) == masked ]] && ! systemctl is-active ${u}"
done
check "systemd-networkd is active" systemctl is-active systemd-networkd
check "network-online waits for networkd, one routable link" bash -c '
    systemctl show -P WantedBy systemd-networkd-wait-online | grep -qw network-online.target &&
    systemctl show -p ExecStart systemd-networkd-wait-online | grep -qF -- "--any --operational-state=routable"'
check "the VM NIC gets DHCP from 99-vm-dhcp.network" bash -c '
    dev=$(ip -4 route show default | awk "{print \$5; exit}") &&
    networkctl status --no-pager "${dev}" | grep -q "Network File: /usr/lib/systemd/network/99-vm-dhcp.network"'
# capi-image-builder's goss: the effective networkd.conf.
check "networkd leaves foreign routes, rules and nexthops" bash -c '
    c=$(systemd-analyze cat-config systemd/networkd.conf) &&
    for k in Routes RoutingPolicyRules NextHops; do grep -qx "ManageForeign${k}=no" <<<"${c}" || exit 1; done'
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
# address and points resolved at it for cluster names.
check "nodelocaldns: DNS for svc.cluster.local, address kept" bash -c '
    sudo ip link add nodelocaldns type dummy && sudo ip addr add 169.254.25.10/32 dev nodelocaldns &&
    sudo ip link set nodelocaldns up || exit 1
    sleep 3; s=$(resolvectl status nodelocaldns); a=$(ip -4 -o addr show dev nodelocaldns)
    sudo ip link del nodelocaldns
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
check "sysctl-mlx5-large is wanted by multi-user.target" bash -c "systemctl show -P WantedBy sysctl-mlx5-large.service | grep -qw multi-user.target"
check "sysctl-mlx5-large skips the test VM" bash -c '[[ $(systemctl show -P ConditionResult sysctl-mlx5-large.service) == no ]]'
# The dedicated servers' sysctls: the test VM keeps the kernel default.
check "sysctl-metal is wanted by multi-user.target" bash -c "systemctl show -P WantedBy sysctl-metal.service | grep -qw multi-user.target"
check "sysctl-metal skips the test VM" bash -c '[[ $(systemctl show -P ConditionResult sysctl-metal.service) == no ]]'
check "sysctl net.core.rmem_default" bash -c '[[ $(sudo sysctl -n net.core.rmem_default) == 212992 ]]'
for m in overlay br_netfilter; do
    check "module ${m} is loaded" bash -c "lsmod | grep -q ^${m}"
done
check "usb-storage is blacklisted" bash -c 'modprobe -c | grep -qx "blacklist usb_storage"'

# udev (goss: 60-qemu-disk-readahead.rules; the etcd and OpenStack rules).
for r in 60-qemu-disk-readahead 99-openstack-by-tag; do
    check "udev rule ${r} is valid" udevadm verify "/usr/lib/udev/rules.d/${r}.rules"
done
check "disk-by-tag helper prints nothing without OpenStack metadata" bash -c '[[ -z $(ID_SERIAL_SHORT=x /usr/libexec/openstack-disk-by-tag) ]]'

# Scripts: they parse, and what they need is there.
for s in /usr/libexec/openstack-fetch-metadata /usr/libexec/openstack-disk-by-tag \
    /usr/libexec/etcd-network-tuning.sh; do
    check "${s} parses" bash -n "${s}"
done
check "RAID and LUKS tools" bash -c 'for c in mdadm cryptsetup systemd-cryptenroll pvcreate vgcreate networkctl tc; do command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }; done'
check "TPM2 libraries for systemd-cryptenroll" bash -c 'out=$(systemd-analyze has-tpm2 || true); for l in esys rc mu; do grep -q -- "+libtss2-${l}.so" <<<"${out}" || { echo "missing: ${l}"; exit 1; }; done'
check "kubelet plugin directory" test -d /usr/libexec/kubernetes/kubelet-plugins/volume/exec
