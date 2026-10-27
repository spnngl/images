# k3s: references

## Sources

- k3s: `github.com/k3s-io/k3s` at `INSTALL_K3S_VERSION`;
  <https://docs.k3s.io>
- CRI-O: `github.com/cri-o/cri-o`; packages
  <https://github.com/cri-o/packaging>
- Cilium: `github.com/cilium/cilium`; <https://docs.cilium.io>
- kine (k3s' SQLite datastore): `github.com/k3s-io/kine` at the version
  in k3s' `go.mod`

## Decisions

- **Bind-mounted, not copied:** the script stays out of the image;
  buildah still keys its cache on its content.
- **Tag carries the Kubernetes minor release only:** k3s upgrades in
  place within a minor release, so patch releases and new k3s builds
  reach hosts with `bootc upgrade`; only a minor release, a new tag,
  needs `bootc switch`, the moment to read Kubernetes' upgrade notes.
- **`kube.slice`:** out of `system.slice` (bootc/K3S.md, "Swap").
- **`systemReserved`, no `enforceNodeAllocatable` beyond `pods`**
  (`kubelet.conf.d/20-my-kubelet.conf`): pods could request, and use,
  all of a node's RAM; on the 3.8GiB control plane memory pressure
  stalled the API server and failed the liveness probes calling it
  (kube-state-metrics, metrics-server). The reservation lowers
  allocatable and `kubepods.slice`'s limit
  (`pkg/kubelet/cm/node_container_manager_linux.go`). Enforcing it on
  `system.slice` or `kube.slice` would cap the daemons themselves: an
  OOM kill of k3s is worse than a slow one.
- **`kubeReserved` on the control-plane only**
  (`/etc/rancher/k3s/kubelet-server.conf`): `k3s server` holds the
  datastore and the API server, 1.7-1.9GiB; an agent's k3s is far
  smaller. The image's kubelet drop-ins are shared by both roles, so
  the file is passed from the server's `config.yaml` with
  `kubelet-arg: config=`, which k3s copies into its drop-in directory
  as `10-cli-config.conf` (`extractConfigArgs()`,
  `pkg/daemons/agent/agent.go`); dropping the flag leaves that copy
  behind. 1Gi, not k3s' whole footprint: that would leave pods
  ~1.6GiB, under the 2.2GiB they request. It does not prevent the daily memory stalls (02:43 UTC,
  with I/O pressure from swap-ins), whose cause is unknown.
- **Kubelet drop-ins in `/usr/lib/rancher/k3s/kubelet.conf.d`,**
  passed by both units with `--kubelet-arg=config-dir=`
  (`bootc/k3s/install.sh`): in k3s' own drop-in directory, in `/var`,
  they reached a host only at install, and every change was copied by
  hand. k3s copies the directory there as `20-cli-config-dir/` at each
  start (`extractConfigArgs()`); the kubelet reads it recursively, in
  name order (`mergeKubeletConfigurations()`,
  kubernetes `cmd/kubelet/app/server.go`). A file removed from the
  image stays in that copy until deleted by hand.
- **Pods `NoSwap`** (`kubelet.conf.d/20-my-kubelet.conf`): with
  `LimitedSwap` a Burstable container whose memory request is below its
  limit may swap, and the kubelet rejects an in-place change of its
  memory request (`disallowResizeForSwappableContainers`,
  `pkg/kubelet/allocation/handlers.go`, kubernetes/kubernetes#130831):
  `PodResizePending` `Infeasible`, "In-place resize of containers with
  swap is not supported". VPA's `InPlaceOrRecreate` then falls back to
  eviction, which its eviction limiter refuses for a single replica: the
  pods kept their creation-time requests. A memory `resizePolicy` of
  `RestartContainer` passes the check, but restarts the container on
  every memory resize. Pods swapped little (182Mi on the control plane,
  under 1Mi elsewhere); the host daemons, which swap more, keep zram.
- **`KINE_COMPACT_TIMEOUT=60s`** (`k3s.service.d/20-kine-compact-timeout.conf`):
  a slow disk must not stop the server. kine's compaction runs in a
  transaction whose context times out after `--compact-timeout` (5s,
  `pkg/app/app.go`), while its statements run without that deadline
  (`compact()`, `pkg/logstructured/sqllog/sql.go`). Past the deadline
  `database/sql` rolls the transaction back, `MustCommit()` gets
  `sql.ErrTxDone` and calls `logrus.Fatalf` (`pkg/drivers/generic/tx.go`):
  `Transaction commit failed: sql: transaction has already been committed
  or rolled back`. Seen on an OVH VPS during daily host-side disk latency
  (await 0.35ms to 6-54ms): compactions took 10-18s. k3s builds kine's
  config by parsing kine's flags (`DefaultEndpointConfig()`,
  `pkg/etcd/etcd.go`), so the flag's environment variable applies. A
  longer compaction holds SQLite's write lock longer: writes wait instead
  of the server restarting.
- **UDP buffer ceilings 16 MiB** (`sysctl.d/60-udp-buffers.conf`): LiveKit
  (tuwunel calls) sets 16 MiB read and write buffers on its UDP mux
  (`defaultUDPBufferSize`, mediatransportutil `pkg/rtcconfig/config.go`,
  `webrtc_config.go`), capped by the kernel at `rmem_max` / `wmem_max`,
  212992 bytes by default (`sk_setsockopt()`, linux `net/core/sock.c`).
  At start it reads its `SO_RCVBUF` back, doubled by the kernel, and
  warns below `minUDPBufferSize` 5000000 (`rtc_unix.go`): "UDP receive
  buffer is too small for a production set-up", current 425984. The
  host's value reaches pods: both sysctls are global, read-only in
  other network namespaces (`sysctl_core_net_init()`,
  `net/core/sysctl_net_core.c`, v6.12).
- **CRI-O `included_pod_metrics`** (`crio.conf.d/20-k3s.conf`): with the
  kubelet's `PodAndContainerStatsFromCRI`, `/metrics/cadvisor` comes from
  CRI-O's `ListPodSandboxMetrics`, which only exports the listed groups;
  the default is empty (`pkg/config/config.go`). PSI, file descriptors
  and sockets are read on every collection whatever the list
  (`internal/config/cgmgr/stats_linux.go`): `pressure` and `process`
  only add series.
- **CRI-O `collection_period = 10`** (`crio.conf.d/20-k3s.conf`): with
  the default, 0, each stats request collects anew, walking every file
  of every container's rootfs (`DiskStats`, `internal/oci/runtime_oci.go`,
  `internal/lib/stats/disk_stats_linux.go`): ~22s per call on the Atom
  C2338. With a period, samples carry the collection's timestamp, so
  `rate()` needs two collections in its window. Up to CRI-O 1.37.2 the
  periodic update (`updateSandbox`,
  `internal/lib/statsserver/stats_server_linux.go`) never refreshes the
  container stats: `ListContainerStats` serves the first sample forever,
  `usageNanoCores` is missing, and the kubelet computes it from its own
  calls (`pkg/kubelet/stats/cri_stats_provider.go`), logging "zero or
  negative interval" when two read the same sample. Fix:
  <https://github.com/cri-o/cri-o/pull/10465>; once released, a longer
  period would do.
