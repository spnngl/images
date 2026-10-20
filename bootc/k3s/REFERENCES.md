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
