# k3s: references

## Sources

- k3s: `github.com/k3s-io/k3s` at `INSTALL_K3S_VERSION`;
  <https://docs.k3s.io>
- CRI-O: `github.com/cri-o/cri-o`; packages
  <https://github.com/cri-o/packaging>
- Cilium: `github.com/cilium/cilium`; <https://docs.cilium.io>

## Decisions

- **Bind-mounted, not copied:** the script stays out of the image;
  buildah still keys its cache on its content.
- **Tag carries the Kubernetes minor release only:** k3s upgrades in
  place within a minor release, so patch releases and new k3s builds
  reach hosts with `bootc upgrade`; only a minor release, a new tag,
  needs `bootc switch`, the moment to read Kubernetes' upgrade notes.
- **`kube.slice`:** out of `system.slice` (bootc/K3S.md, "Swap").
