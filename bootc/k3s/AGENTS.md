# k3s

Shared by every bootc image's `kubeenv` stage, not an image. The stage
bind-mounts `install.sh` to run it (reasons next to each step),
then copies `sysroot/`. Host setup (roles, swap, Cilium, firewall):
[bootc/K3S.md](../K3S.md). Upstream sources and the reason for each
choice: [REFERENCES.md](REFERENCES.md).

## Rules

- `install.sh` installs k3s in `/usr` with one unit per role, both
  disabled: each host picks its role by hand.
- The k3s release (`v<Kubernetes release>+k3s<build>`) is the stage's
  `ARG INSTALL_K3S_VERSION`, set by Bake from the `K3S` variable of
  `bootc/docker-bake.hcl`, which Renovate updates. The tag suffix,
  `-v<minor>k3s`, is computed from it (`line()`).

## Updates

k3s builds and Kubernetes patch and minor releases are automerged. A
minor release fails CI until CRI-O publishes its repository: re-run the
PR's checks then. It changes the tag: move hosts with `bootc switch`,
following Kubernetes' upgrade notes.

## Limits

Cilium runs with `kubeProxyReplacement=true`, handling NodePort and
LoadBalancer traffic in eBPF before netfilter: cs-firewall-bouncer
doesn't cover it.
